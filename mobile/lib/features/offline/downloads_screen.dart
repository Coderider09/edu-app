import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/ui.dart';
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

    return Scaffold(
      appBar: AppBar(title: Text(s['offline_materials'])),
      body: AsyncBody<PackManifest>(
        value: manifest,
        onRetry: () => ref.invalidate(packManifestProvider),
        builder: (m) {
          final missing = m.packs.where((p) => !_upToDate(p)).toList();
          final missingSize = missing.fold<int>(0, (sum, p) => sum + p.sizeBytes);
          final done = m.packs.length - missing.length;
          return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
            FadeSlideIn(
              child: AuroraBackground(
                colors: const [Color(0xFF059669), Color(0xFF10B981), Color(0xFF06B6D4)],
                borderRadius: BorderRadius.circular(Radii.lg),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      ProgressRing(
                        value: m.packs.isEmpty ? 0 : done / m.packs.length,
                        size: 76,
                        stroke: 8,
                        colors: const [Colors.white, Color(0xFFD1FAE5)],
                        track: Colors.white24,
                        child: Text('$done/${m.packs.length}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(s['offline_intro'],
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, height: 1.35)),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    SmoothSwitcher(
                      child: missing.isEmpty
                          ? Row(key: const ValueKey('all'), children: [
                              const Icon(Icons.verified_rounded, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(s['all_downloaded'],
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                            ])
                          : Pressable(
                              key: const ValueKey('download'),
                              onTap: _progress.isEmpty ? () => _download(missing) : null,
                              child: Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(Radii.md),
                                ),
                                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  const Icon(Icons.download_rounded, color: Color(0xFF059669)),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(s.f('download_all', {'size': _size(s, missingSize)}),
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Color(0xFF059669), fontWeight: FontWeight.w900, fontSize: 15)),
                                  ),
                                ]),
                              ),
                            ),
                    ),
                  ]),
                ),
              ),
            ),
            if (pending > 0) ...[
              const SizedBox(height: 12),
              FadeSlideIn(
                delay: Stagger.of(1),
                child: AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    const Pulse(
                      amplitude: 0.08,
                      child: IconBadge(Icons.cloud_upload_rounded, colors: AppGradients.sky, size: 44),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(s.f('pending_sync', {'n': pending}),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    _syncing
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
                        : Pressable(
                            onTap: _sync,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(
                                gradient: AppGradients.of(AppGradients.sky),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(s['sync_now'],
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                            ),
                          ),
                  ]),
                ),
              ),
            ],
            SectionHeader(s['subjects']),
            for (var i = 0; i < m.packs.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FadeSlideIn(
                  delay: Stagger.of(i + 2),
                  child: _PackTile(
                    pack: m.packs[i],
                    colors: _packColors[i % _packColors.length],
                    title: m.packs[i].title(lang),
                    progress: _progress[m.packs[i].subjectId],
                    installed: _store.isInstalled(m.packs[i].subjectId),
                    upToDate: _upToDate(m.packs[i]),
                    onDownload: _progress.isEmpty ? () => _download([m.packs[i]]) : null,
                    onRemove: () => _remove(m.packs[i]),
                  ),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

const _packColors = [
  AppGradients.violet,
  AppGradients.fire,
  AppGradients.sky,
  AppGradients.mint,
  AppGradients.rose,
  AppGradients.gold,
];

class _PackTile extends ConsumerWidget {
  final PackInfo pack;
  final List<Color> colors;
  final String title;
  final double? progress;
  final bool installed;
  final bool upToDate;
  final VoidCallback? onDownload;
  final VoidCallback onRemove;
  const _PackTile({
    required this.pack,
    required this.colors,
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
    final details = s.f('pack_details', {'questions': pack.questions, 'size': _size(s, pack.sizeBytes)});
    final Widget trailing;
    if (progress != null) {
      trailing = ProgressRing(
        key: const ValueKey('progress'),
        value: progress!,
        size: 40,
        stroke: 4,
        colors: colors,
        duration: const Duration(milliseconds: 150),
        child: Text('${(progress! * 100).round()}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
      );
    } else if (installed && upToDate) {
      trailing = PopupMenuButton<String>(
        key: const ValueKey('done'),
        icon: const Icon(Icons.check_circle_rounded, color: AppColors.correct, size: 28),
        onSelected: (_) => onRemove(),
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'delete',
            child: Row(children: [
              const Icon(Icons.delete_outline_rounded, color: AppColors.wrong),
              const SizedBox(width: 8),
              Text(s['delete']),
            ]),
          ),
        ],
      );
    } else if (installed) {
      trailing = Pill(s['update'], key: const ValueKey('update'), icon: Icons.refresh_rounded, color: colors.first);
    } else {
      trailing = Container(
        key: const ValueKey('download'),
        width: 40,
        height: 40,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppGradients.of(colors)),
        child: const Icon(Icons.download_rounded, color: Colors.white, size: 22),
      );
    }
    final tappable = progress == null && !(installed && upToDate);
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: tappable ? onDownload : null,
      child: Row(children: [
        IconBadge(Icons.inventory_2_rounded, colors: colors, size: 46, glow: false),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 3),
            Text(installed ? '$details · ${s[upToDate ? 'downloaded' : 'update_available']}' : details,
                style: TextStyle(color: mutedOf(context), fontSize: 12.5)),
            if (progress != null) ...[
              const SizedBox(height: 8),
              GradientBar(value: progress!, colors: colors, height: 6),
            ],
          ]),
        ),
        const SizedBox(width: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
          child: trailing,
        ),
      ]),
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
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: FadeSlideIn(
        delay: const Duration(milliseconds: 300),
        child: AppCard(
          onTap: () => context.push('/downloads'),
          gradient: AppGradients.of([
            AppGradients.mint.first.withValues(alpha: 0.16),
            AppGradients.sky.first.withValues(alpha: 0.16),
          ]),
          border: Border.all(color: AppGradients.mint.first.withValues(alpha: 0.35)),
          child: Row(children: [
            const Float(
                distance: 3, child: IconBadge(Icons.cloud_download_rounded, colors: AppGradients.mint, size: 48)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s['offline_banner_title'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                Text(s['offline_banner_text'], style: TextStyle(color: mutedOf(context), fontSize: 13)),
              ]),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: mutedOf(context)),
          ]),
        ),
      ),
    );
  }
}
