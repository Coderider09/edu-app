import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../config/app_config.dart';
import '../core/api/api_client.dart';
import '../data/models.dart';
import '../features/auth/session_controller.dart';
import 'offline_testing.dart';

/// Number of offline results/lessons/marks waiting for upload (shown on the downloads screen).
final pendingSyncProvider = StateProvider<int>((ref) => 0);

/// Increments after every successful upload so screens with server data reload.
final syncTickProvider = StateProvider<int>((ref) => 0);

const _maxAttemptsPerRequest = 50;

/// Uploads work done offline through POST /sync: on start, when the app comes back to the
/// foreground, after an offline test and periodically while something is waiting.
class SyncService {
  final Ref ref;
  SyncService(this.ref);

  Future<bool>? _running;
  Timer? _timer;

  Box<String> get _box => Hive.box<String>(AppConfig.syncBox);
  OfflineTesting get _offline => ref.read(offlineTestingProvider);

  // ------------------------------------------------------------------ queues
  List<Map<String, dynamic>> get _lessons => [
        for (final e in jsonDecode(_box.get('lessons') ?? '[]') as List) Map<String, dynamic>.from(e as Map),
      ];

  Map<String, bool> get _marks => Map<String, bool>.from(jsonDecode(_box.get('marks') ?? '{}') as Map);

  Set<int> get queuedLessonIds => {for (final l in _lessons) l['lesson_id'] as int};

  Future<void> queueLesson(int lessonId) async {
    final lessons = _lessons;
    if (lessons.any((l) => l['lesson_id'] == lessonId)) return;
    lessons.add({'lesson_id': lessonId, 'completed_at': DateTime.now().toUtc().toIso8601String()});
    await _box.put('lessons', jsonEncode(lessons));
    _updateCount();
  }

  Future<void> queueMark(int questionId, bool marked) async {
    final marks = _marks..['$questionId'] = marked;
    await _box.put('marks', jsonEncode(marks));
    _updateCount();
  }

  int get pendingCount => _offline.pendingAttempts().length + _lessons.length + _marks.length;

  void _updateCount() => ref.read(pendingSyncProvider.notifier).state = pendingCount;

  // ------------------------------------------------------------------ upload
  void start() {
    _updateCount();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (pendingCount > 0) run();
    });
  }

  /// Returns true when everything was uploaded.
  Future<bool> run() => _running ??= _run().whenComplete(() => _running = null);

  Future<bool> _run() async {
    if (ref.read(sessionProvider).status != SessionStatus.ready) return false;
    var synced = false;
    try {
      while (true) {
        final attempts = _offline.pendingAttempts()
          ..sort((a, b) => '${a['finished_at']}'.compareTo('${b['finished_at']}'));
        final batch = attempts.take(_maxAttemptsPerRequest).toList();
        final lessons = _lessons;
        final marks = _marks;
        if (batch.isEmpty && lessons.isEmpty && marks.isEmpty) return true;

        Map<String, dynamic> response;
        try {
          response = Map<String, dynamic>.from(await ref.read(apiClientProvider).post('/sync', data: {
            'attempts': [
              for (final a in batch)
                {
                  'client_id': a['client_id'],
                  'test_type': a['test_type'],
                  'reference_id': a['reference_id'],
                  'question_ids': a['question_ids'],
                  'started_at': a['started_at'],
                  'finished_at': a['finished_at'],
                  'answers': [
                    for (final ans in a['answers'] as List)
                      {'question_id': ans['question_id'], 'answer': ans['answer'], 'answered_at': ans['answered_at']},
                  ],
                },
            ],
            'lessons': lessons,
            'marked': [for (final e in marks.entries) if (e.value) int.parse(e.key)],
            'unmarked': [for (final e in marks.entries) if (!e.value) int.parse(e.key)],
          }));
        } on ApiException catch (e) {
          // 422: a record the server can never accept — drop it instead of retrying forever
          if (e.statusCode != 422) return false;
          response = {'attempts': [for (final a in batch) {'client_id': a['client_id']}]};
        }

        for (final r in response['attempts'] as List? ?? const []) {
          await _offline.markSynced('${r['client_id']}');
        }
        // Keep what was queued while the request was running
        final sentLessons = {for (final l in lessons) l['lesson_id']};
        await _box.put('lessons', jsonEncode(_lessons.where((l) => !sentLessons.contains(l['lesson_id'])).toList()));
        final leftMarks = _marks..removeWhere((k, v) => marks[k] == v);
        await _box.put('marks', jsonEncode(leftMarks));

        if (response['profile'] != null) {
          ref.read(sessionProvider.notifier).setProfile(Profile.fromJson(Map<String, dynamic>.from(response['profile'])));
        }
        synced = true;
        if (attempts.length <= _maxAttemptsPerRequest) return true;
      }
    } finally {
      _updateCount();
      if (synced) ref.read(syncTickProvider.notifier).state++;
    }
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(ref);
  ref.onDispose(() => service._timer?.cancel());
  return service;
});
