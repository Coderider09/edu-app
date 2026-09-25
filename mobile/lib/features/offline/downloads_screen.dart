import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/l10n/strings.dart';
import '../../core/settings.dart';
import '../../core/widgets/common.dart';
import '../../offline/pack_store.dart';
import '../../offline/sync_service.dart';

/// Packs of the user's cluster/grade; offline the last known list is shown.
final packManifestProvider = FutureProvider.autoDispose<PackManifest>((ref) async {
  final store = ref.watch(packStoreProvider);
  try {
    return await store.fetchManifest();
  } on ApiException catch (e) {
    final saved = store.savedManifest;
    if (e.offline && saved != null) return saved;
    rethrow;
  }
});

String _size(Strings s, int bytes) => s.f('mb', {'n': (bytes / (1024 * 1024)).toStringAsFixed(1)});

/// "Офлайн-материалы": download, update and remove subject packs; upload results done offline.
class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  final _progress = <int, double>{};
  bool _syncing = false;

  PackStore get _store => ref.read(packStoreProvider);

  bool _upToDate(PackInfo p) => _store.installed[p.subjectId]?.version == p.version;

  Future<void> _download(List<PackInfo> packs) async {
    final s = ref.read(stringsProvider);
    for (final p in packs) {
      if (_progress.containsKey(p.subjectId)) continue;
      setState(() => _progress[p.subjectId] = 0);
      try {
        await _store.download(p, onProgress: (v) {
          if (mounted) setState(() => _progress[p.subjectId] = v);
        });
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s['download_failed'])));
        if (mounted) setState(() => _progress.remove(p.subjectId));
        return;
      }
      if (mounted) setState(() => _progress.remove(p.subjectId));
    }
  }

  Future<void> _remove(PackInfo p) async {
    await _store.remove(p.subjectId);
    if (mounted) setState(() {});
  }

  Future<void> _sync() async {
    final s = ref.read(stringsProvider);
    setState(() => _syncing = true);
    final ok = await ref.read(syncServiceProvider).run();
    if (!mounted) return;
    setState(() => _syncing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s[ok ? 'sync_done' : 'sync_failed'])));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final lang = ref.watch(settingsProvider).language;
    final pending = ref.watch(pendingSyncProvider);
    final manifest = ref.watch(packManifestProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(s['offline_materials'])),
      body: AsyncBody<PackManifest>(
        value: manifest,
        onRetry: () => ref.invalidate(packManifestProvider),
        builder: (m) {
          final missing = m.packs.where((p) => !_upToDate(p)).toList();
          final missingSize = missing.fold<int>(0, (sum, p) => sum + p.sizeBytes);
          return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Icon(Icons.download_for_offline_rounded, color: scheme.primary, size: 32),
                    const SizedBox(width: 12),
                    Expanded(child: Text(s['offline_intro'])),
                  ]),
                  const SizedBox(height: 12),
                  if (missing.isEmpty)
                    Row(children: [
                      Icon(Icons.check_circle_rounded, color: scheme.primary),
                      const SizedBox(width: 8),
                      Text(s['all_downloaded']),
                    ])
                  else
                    FilledButton.icon(
                      icon: const Icon(Icons.download_rounded),
                      label: Text(s.f('download_all', {'size': _size(s, missingSize)})),
                      onPressed: _progress.isEmpty ? () => _download(missing) : null,
                    ),
                ]),
              ),
            ),
            if (pending > 0) ...[
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud_upload_rounded),
                  title: Text(s.f('pending_sync', {'n': pending})),
                  trailing: _syncing
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : TextButton(onPressed: _sync, child: Text(s['sync_now'])),
                ),
              ),
            ],
            SectionTitle(s['subjects']),
            for (final p in m.packs) _PackTile(
              pack: p,
              title: p.title(lang),
              progress: _progress[p.subjectId],
              installed: _store.isInstalled(p.subjectId),
              upToDate: _upToDate(p),
              onDownload: _progress.isEmpty ? () => _download([p]) : null,
              onRemove: () => _remove(p),
            ),
          ]);
        },
      ),
    );
  }
}

class _PackTile extends ConsumerWidget {
  final PackInfo pack;
  final String title;
  final double? progress;
  final bool installed;
  final bool upToDate;
  final VoidCallback? onDownload;
  final VoidCallback onRemove;
  const _PackTile({
    required this.pack,
    required this.title,
    required this.progress,
    required this.installed,
    required this.upToDate,
    required this.onDownload,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final scheme = Theme.of(context).colorScheme;
    final details = s.f('pack_details', {'questions': pack.questions, 'size': _size(s, pack.sizeBytes)});
    final Widget trailing;
    if (progress != null) {
      trailing = SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(value: progress! > 0 ? progress : null, strokeWidth: 3),
      );
    } else if (installed && upToDate) {
      trailing = PopupMenuButton<String>(
        icon: Icon(Icons.check_circle_rounded, color: scheme.primary),
        onSelected: (_) => onRemove(),
        itemBuilder: (_) => [PopupMenuItem(value: 'delete', child: Text(s['delete']))],
      );
    } else if (installed) {
      trailing = FilledButton.tonal(onPressed: onDownload, child: Text(s['update']));
    } else {
      trailing = IconButton(
        icon: const Icon(Icons.download_rounded),
        tooltip: s['download'],
        onPressed: onDownload,
      );
    }
    return Card(
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(installed
            ? '$details · ${s[upToDate ? 'downloaded' : 'update_available']}'
            : details),
        trailing: trailing,
      ),
    );
  }
}

/// Dashboard invitation to download the materials while nothing is downloaded yet.
class OfflinePromoCard extends ConsumerWidget {
  const OfflinePromoCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(packStoreProvider).installed.isNotEmpty) return const SizedBox.shrink();
    final s = ref.watch(stringsProvider);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        color: scheme.secondaryContainer,
        child: ListTile(
          leading: Icon(Icons.download_for_offline_rounded, color: scheme.onSecondaryContainer, size: 32),
          title: Text(s['offline_banner_title'], style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(s['offline_banner_text']),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.push('/downloads'),
        ),
      ),
    );
  }
}
