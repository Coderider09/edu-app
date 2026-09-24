import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../auth/session_controller.dart';

final progressProvider = FutureProvider.autoDispose<List<SubjectProgress>>((ref) {
  ref.watch(sessionProvider.select((s) => s.profile?.activeRole));
  return ref.watch(profileRepositoryProvider).progress();
});
final historyProvider = FutureProvider.autoDispose<List<HistoryItem>>((ref) {
  ref.watch(sessionProvider.select((s) => s.profile?.activeRole));
  return ref.watch(profileRepositoryProvider).history();
});
final achievementsProvider =
    FutureProvider.autoDispose<List<AchievementInfo>>((ref) => ref.watch(profileRepositoryProvider).achievements());

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(progressProvider);
    ref.invalidate(historyProvider);
    ref.invalidate(achievementsProvider);
    await ref.read(sessionProvider.notifier).refreshProfile();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final profile = ref.watch(sessionProvider).profile;
    if (profile == null) return const Scaffold(body: SkeletonList());

    return Scaffold(
      appBar: AppBar(
        title: Text(s['profile']),
        actions: [
          IconButton(icon: const Icon(Icons.settings_rounded), onPressed: () => context.push('/settings')),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
          _ProfileHeader(profile: profile),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: _MiniStat(
                icon: Icons.local_fire_department_rounded,
                color: AppColors.streak,
                value: '${profile.currentStreak}',
                label: s.f('best_streak', {'n': profile.longestStreak}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MiniStat(
                icon: Icons.star_rounded,
                color: AppColors.gold,
                value: '${profile.totalPoints}',
                label: s['points'],
              ),
            ),
          ]),
          SectionTitle(s['progress_by_subjects']),
          ref.watch(progressProvider).when(
                loading: () => const Skeleton(height: 120),
                error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(progressProvider)),
                data: (list) => TapCard(child: _ProgressBars(items: list)),
              ),
          SectionTitle(s['achievements']),
          ref.watch(achievementsProvider).when(
                loading: () => const Skeleton(height: 100),
                error: (e, _) => const SizedBox.shrink(),
                data: (list) => _AchievementsGrid(items: list),
              ),
          SectionTitle(s['history']),
          ref.watch(historyProvider).when(
                loading: () => const Skeleton(height: 80),
                error: (e, _) => const SizedBox.shrink(),
                data: (list) => list.isEmpty
                    ? Text(s['history_empty'])
                    : Column(children: [
                        for (final h in list)
                          Padding(padding: const EdgeInsets.only(bottom: 8), child: _HistoryTile(item: h)),
                      ]),
              ),
        ]),
      ),
    );
  }
}

class _ProfileHeader extends ConsumerWidget {
  final Profile profile;
  const _ProfileHeader({required this.profile});

  Future<void> _chooseAvatar(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(s['choose_avatar'], style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Wrap(spacing: 12, runSpacing: 12, children: [
              for (final id in avatarEmoji.keys)
                GestureDetector(
                  onTap: () => Navigator.pop(context, id),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: id == profile.avatarId ? Theme.of(context).colorScheme.primary : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: AvatarCircle(id, size: 56),
                  ),
                ),
            ]),
          ]),
        ),
      ),
    );
    if (chosen == null || chosen == profile.avatarId) return;
    try {
      final updated = await ref.read(profileRepositoryProvider).update({'avatar_id': chosen});
      ref.read(sessionProvider.notifier).setProfile(updated);
    } catch (e) {
      if (context.mounted) showError(context, s, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final subtitle = profile.isAbiturient
        ? (profile.abiturient?.clusterTitle ?? s['role_name_abiturient'])
        : s.f('grade_n', {'n': profile.school?.grade ?? ''});
    final next = profile.level.nextCode;
    return TapCard(
      child: Column(children: [
        Row(children: [
          GestureDetector(
            onTap: () => _chooseAvatar(context, ref),
            child: Stack(alignment: Alignment.bottomRight, children: [
              Hero(tag: 'avatar', child: AvatarCircle(profile.avatarId, size: 76)),
              const CircleAvatar(radius: 12, child: Icon(Icons.edit_rounded, size: 14)),
            ]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(profile.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 6),
              Text('${s['level']} ${profile.level.number} · ${s.level(profile.level.code)}',
                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w800)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        AnimatedProgressBar(value: profile.level.progress),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            next == null
                ? s['max_level']
                : s.f('to_next_level',
                    {'level': s.level(next), 'n': (profile.level.nextLevelPoints ?? 0) - profile.totalPoints}),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  const _MiniStat({required this.icon, required this.color, required this.value, required this.label});

  @override
  Widget build(BuildContext context) => TapCard(
        child: Row(children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              Text(label, style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
      );
}

/// Horizontal bars per subject: studied material and answer accuracy.
class _ProgressBars extends ConsumerWidget {
  final List<SubjectProgress> items;
  const _ProgressBars({required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    if (items.isEmpty) return Text(s['no_subjects']);
    return Column(children: [
      for (final p in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(p.title, style: const TextStyle(fontWeight: FontWeight.w700))),
              Text('${s['material']} ${p.percent}% · ${s['accuracy']} ${p.accuracy}%',
                  style: Theme.of(context).textTheme.bodySmall),
            ]),
            const SizedBox(height: 6),
            AnimatedProgressBar(value: p.percent / 100, color: parseHexColor(p.color)),
            const SizedBox(height: 4),
            AnimatedProgressBar(value: p.accuracy / 100, color: AppColors.correct, height: 4),
          ]),
        ),
    ]);
  }
}

class _AchievementsGrid extends StatelessWidget {
  final List<AchievementInfo> items;
  const _AchievementsGrid({required this.items});

  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.85,
        children: [
          for (final a in items)
            Tooltip(
              message: a.description ?? a.title,
              triggerMode: TooltipTriggerMode.tap,
              child: Opacity(
                opacity: a.unlocked ? 1 : 0.35,
                child: TapCard(
                  padding: const EdgeInsets.all(10),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: a.unlocked ? AppColors.gold : Colors.grey,
                      child: Icon(a.unlocked ? achievementIcon(a.icon) : Icons.lock_rounded, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(a.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
        ],
      );
}

class _HistoryTile extends ConsumerWidget {
  final HistoryItem item;
  const _HistoryTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final color = item.accuracy >= 80 ? AppColors.correct : (item.accuracy >= 50 ? AppColors.gold : AppColors.wrong);
    final date = item.finishedAt;
    return TapCard(
      onTap: () => context.push('/result/${item.id}'),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
          child: Text(item.mmtScore != null ? '${item.mmtScore}' : '${item.accuracy}%',
              style: TextStyle(color: color, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(
              '${s['test_type_${item.testType}']} · ${item.correctCount}/${item.totalCount}'
              '${date != null ? ' · ${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ]),
        ),
        Text('+${item.score}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.gold)),
      ]),
    );
  }
}
