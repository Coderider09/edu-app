import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';
import '../core/api/api_client.dart';
import 'engine.dart';

int _int(dynamic v) => v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

/// A pack available on the server (GET /packs).
class PackInfo {
  final int subjectId;
  final String? code;
  final String titleRu;
  final String titleTj;
  final String version;
  final int sizeBytes;
  final int questions;
  final int lessons;
  const PackInfo(this.subjectId, this.code, this.titleRu, this.titleTj, this.version, this.sizeBytes, this.questions,
      this.lessons);

  String title(String lang) => lang == 'tj' && titleTj.isNotEmpty ? titleTj : titleRu;

  factory PackInfo.fromJson(Map<String, dynamic> j) => PackInfo(_int(j['subject_id']), j['code'],
      j['title_ru'] ?? '', j['title_tj'] ?? '', j['version'] ?? '', _int(j['size_bytes']), _int(j['questions']),
      _int(j['lessons']));
}

class PackManifest {
  final List<ClusterStructure> clusters;
  final List<PackInfo> packs;
  const PackManifest(this.clusters, this.packs);

  factory PackManifest.fromJson(Map<String, dynamic> j) => PackManifest(
        (j['clusters'] as List? ?? const [])
            .map((e) => ClusterStructure.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        (j['packs'] as List? ?? const []).map((e) => PackInfo.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      );
}

/// A pack unpacked on this device. Topic and lesson ids let screens find the pack without opening it.
class InstalledPack {
  final int subjectId;
  final String version;
  final int sizeBytes;
  final DateTime installedAt;
  final Set<int> topicIds;
  final Set<int> lessonIds;
  const InstalledPack(this.subjectId, this.version, this.sizeBytes, this.installedAt, this.topicIds, this.lessonIds);

  Map<String, dynamic> toJson() => {
        'subject_id': subjectId,
        'version': version,
        'size_bytes': sizeBytes,
        'installed_at': installedAt.toIso8601String(),
        'topic_ids': topicIds.toList(),
        'lesson_ids': lessonIds.toList(),
      };

  factory InstalledPack.fromJson(Map<String, dynamic> j) => InstalledPack(
        _int(j['subject_id']),
        j['version'] ?? '',
        _int(j['size_bytes']),
        DateTime.tryParse('${j['installed_at']}') ?? DateTime.now(),
        {for (final id in (j['topic_ids'] as List? ?? const [])) _int(id)},
        {for (final id in (j['lesson_ids'] as List? ?? const [])) _int(id)},
      );
}

/// Unzips a pack into [dest] (runs in a background isolate). Returns the ids indexed in [InstalledPack].
Map<String, dynamic> _extractPack((String, String) args) {
  final (zipPath, dest) = args;
  final archive = ZipDecoder().decodeBytes(File(zipPath).readAsBytesSync());
  for (final file in archive.files) {
    if (!file.isFile) continue;
    final name = file.name.replaceAll('\\', '/');
    if (name.startsWith('/') || name.split('/').contains('..')) continue; // never write outside the pack
    final out = File('$dest/$name');
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(file.content as List<int>);
  }
  final content = jsonDecode(File('$dest/content.json').readAsStringSync()) as Map<String, dynamic>;
  return {
    'version': content['version'],
    'topic_ids': [for (final t in content['topics'] as List) t['id']],
    'lesson_ids': [for (final l in content['lessons'] as List) l['id']],
  };
}

Map<String, dynamic> _readJson(String path) => jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

// Top-level so the isolate closures capture only the paths (not `this` with its HTTP client)
Future<Map<String, dynamic>> _extractInBackground(String zipPath, String dest) =>
    Isolate.run(() => _extractPack((zipPath, dest)));

Future<Map<String, dynamic>> _readJsonInBackground(String path) => Isolate.run(() => _readJson(path));

/// Downloaded subject packs: manifest, download/update/remove, and loading into memory.
class PackStore {
  final ApiClient api;
  PackStore(this.api);

  final _loaded = <int, SubjectPack>{};
  Directory? _root;

  Box<String> get _box => Hive.box<String>(AppConfig.packsBox);

  Future<Directory> _dir() async {
    if (_root != null) return _root!;
    final base = await getApplicationSupportDirectory();
    return _root = await Directory('${base.path}/packs').create(recursive: true);
  }

  // ------------------------------------------------------------------ manifest
  /// Packs of the user's cluster/grade and the cluster structures; the last one is kept for offline use.
  Future<PackManifest> fetchManifest() async {
    final r = await api.get('/packs', cache: false);
    final data = Map<String, dynamic>.from(r.data as Map);
    await _box.put('manifest', jsonEncode(data));
    return PackManifest.fromJson(data);
  }

  PackManifest? get savedManifest {
    final raw = _box.get('manifest');
    return raw == null ? null : PackManifest.fromJson(Map<String, dynamic>.from(jsonDecode(raw)));
  }

  ClusterStructure? cluster(int clusterId) =>
      savedManifest?.clusters.where((c) => c.id == clusterId).firstOrNull;

  // ------------------------------------------------------------------ installed packs
  Map<int, InstalledPack> get installed {
    final raw = _box.get('installed');
    if (raw == null) return {};
    return {
      for (final e in (jsonDecode(raw) as Map).values)
        _int(e['subject_id']): InstalledPack.fromJson(Map<String, dynamic>.from(e as Map)),
    };
  }

  Future<void> _saveInstalled(Map<int, InstalledPack> packs) =>
      _box.put('installed', jsonEncode({for (final p in packs.values) '${p.subjectId}': p.toJson()}));

  bool isInstalled(int subjectId) => installed.containsKey(subjectId);

  int? subjectForTopic(int topicId) =>
      installed.values.where((p) => p.topicIds.contains(topicId)).firstOrNull?.subjectId;

  int? subjectForLesson(int lessonId) =>
      installed.values.where((p) => p.lessonIds.contains(lessonId)).firstOrNull?.subjectId;

  /// Downloads and unpacks a pack, replacing the installed version only when everything succeeded.
  Future<void> download(PackInfo info, {void Function(double progress)? onProgress}) async {
    final root = await _dir();
    final zip = File('${root.path}/${info.subjectId}.zip');
    final staging = Directory('${root.path}/${info.subjectId}.new');
    final target = Directory('${root.path}/${info.subjectId}');
    try {
      await api.download('/packs/${info.subjectId}/download', zip.path, onProgress: (received, total) {
        final expected = total > 0 ? total : info.sizeBytes;
        if (expected > 0) onProgress?.call((received / expected).clamp(0.0, 1.0) * 0.9);
      });
      if (await staging.exists()) await staging.delete(recursive: true);
      await staging.create(recursive: true);
      final ids = await _extractInBackground(zip.path, staging.path);
      if (await target.exists()) await target.delete(recursive: true);
      await staging.rename(target.path);

      final packs = installed;
      packs[info.subjectId] = InstalledPack(
        info.subjectId,
        '${ids['version']}',
        await zip.length(),
        DateTime.now(),
        {for (final id in ids['topic_ids'] as List) _int(id)},
        {for (final id in ids['lesson_ids'] as List) _int(id)},
      );
      await _saveInstalled(packs);
      _loaded.remove(info.subjectId);
      onProgress?.call(1);
    } finally {
      if (await zip.exists()) await zip.delete();
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  Future<void> remove(int subjectId) async {
    final packs = installed..remove(subjectId);
    await _saveInstalled(packs);
    _loaded.remove(subjectId);
    final dir = Directory('${(await _dir()).path}/$subjectId');
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  // ------------------------------------------------------------------ content
  Future<SubjectPack?> load(int subjectId) async {
    final cached = _loaded[subjectId];
    if (cached != null) return cached;
    if (!isInstalled(subjectId)) return null;
    final dir = '${(await _dir()).path}/$subjectId';
    try {
      final json = await _readJsonInBackground('$dir/content.json');
      return _loaded[subjectId] = SubjectPack.fromJson(json, dir: dir);
    } on FileSystemException {
      await remove(subjectId); // files were cleared by the system: download again
      return null;
    }
  }

  Future<SubjectPack?> forTopic(int topicId) async {
    final id = subjectForTopic(topicId);
    return id == null ? null : load(id);
  }

  Future<SubjectPack?> forLesson(int lessonId) async {
    final id = subjectForLesson(lessonId);
    return id == null ? null : load(id);
  }

  /// Local image path of a pack question, usable with [AppConfig.mediaUrl]-aware widgets.
  static String? imageUrl(SubjectPack pack, PackQuestion q) =>
      q.image == null || pack.dir == null ? null : 'file://${pack.dir}/${q.image}';
}

final packStoreProvider = Provider<PackStore>((ref) => PackStore(ref.watch(apiClientProvider)));
