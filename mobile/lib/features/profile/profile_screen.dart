import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/ui.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../auth/session_controller.dart';
import 'profile_sheets.dart';

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

const _levelCodes = ['novice', 'learner', 'advanced', 'expert', 'master'];

/// Profile: living gradient header with the avatar in a level ring, stats, level path, weekly activity
/// and tabs with subject progress, achievements and test history.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int _tab = 0;

  Future<void> _refresh() async {
    ref.invalidate(progressProvider);
    ref.invalidate(historyProvider);
    ref.invalidate(achievementsProvider);
    await ref.read(sessionProvider.notifier).refreshProfile();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final profile = ref.watch(sessionProvider).profile;
    if (profile == null) return const Scaffold(body: SkeletonList());
    final history = ref.watch(historyProvider).valueOrNull ?? const <HistoryItem>[];

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        edgeOffset: 80,
        child: CustomScrollView(slivers: [
          // The stats card overlaps the bottom of the header: it is pinned to the bottom of a box whose
          // lower part (below the header) is shorter than the card
          SliverToBoxAdapter(
            child: Stack(children: [
              Column(children: [_ProfileHero(profile: profile), const SizedBox(height: 104)]),
              Positioned(
                left: 20,
                right: 20,
                bottom: 12,
                child: FadeSlideIn(
                  delay: const Duration(milliseconds: 150),
                  child: _StatsRow(profile: profile, history: history),
                ),
              ),
            ]),
          ),
          SliverPadding(
            padding: Gap.page.copyWith(top: 0),
            sliver: SliverList.list(children: [
              FadeSlideIn(delay: const Duration(milliseconds: 250), child: _LevelPath(profile: profile)),
              const SizedBox(height: 16),
              FadeSlideIn(delay: const Duration(milliseconds: 350), child: _WeekActivity(history: history)),
              const SizedBox(height: 24),
              FadeSlideIn(
                delay: const Duration(milliseconds: 450),
                child: SlidingSegments<int>(
                  items: [(0, s['tab_progress']), (1, s['tab_achievements']), (2, s['tab_history'])],
                  value: _tab,
                  onChanged: (v) => setState(() => _tab = v),
                ),
              ),
              const SizedBox(height: 16),
              SmoothSwitcher(
                child: KeyedSubtree(
                  key: ValueKey(_tab),
                  child: switch (_tab) {
                    0 => const _ProgressTab(),
                    1 => const _AchievementsTab(),
                    _ => const _HistoryTab(),
                  },
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ProfileHero extends ConsumerWidget {
  final Profile profile;
  const _ProfileHero({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final palette = BranchPalette.of(ref.watch(branchProvider));
    final subtitle = profile.isAbiturient
        ? (profile.abiturient?.clusterTitle ?? s['role_name_abiturient'])
        : s.f('grade_n', {'n': profile.school?.grade ?? ''});
    return AuroraBackground(
      colors: palette.gradient,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 60),
          child: Column(children: [
            Row(children: [
              Text(s['profile'],
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
              const Spacer(),
              GlassIconButton(
                icon: Icons.edit_rounded,
                tooltip: s['edit_profile'],
                onPressed: () => showEditProfileSheet(context, ref, profile),
              ),
              const SizedBox(width: 10),
              GlassIconButton(
                icon: Icons.settings_rounded,
                tooltip: s['settings'],
                onPressed: () => context.push('/settings'),
              ),
            ]),
            const SizedBox(height: 18),
            FadeSlideIn(
              scale: true,
              child: Pressable(
                onTap: () => showEditProfileSheet(context, ref, profile),
                child: Stack(clipBehavior: Clip.none, children: [
                  Hero(
                    tag: 'avatar',
                    child: RingAvatar(
                      avatarId: profile.avatarId,
                      progress: profile.level.progress,
                      size: 118,
                      colors: const [Color(0xFFFFE08A), Colors.white],
                      track: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: AppGradients.of(AppGradients.gold),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Text('${profile.level.number}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            FadeSlideIn(
              delay: const Duration(milliseconds: 80),
              child: Text(profile.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            ),
            const SizedBox(height: 8),
            FadeSlideIn(
              delay: const Duration(milliseconds: 140),
              child: Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
                Pill(subtitle,
                    icon: profile.isAbiturient ? Icons.school_rounded : Icons.backpack_rounded, onDark: true),
                Pill('${s['level']} ${profile.level.number} · ${s.level(profile.level.code)}',
                    icon: Icons.workspace_premium_rounded, onDark: true),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _StatsRow extends ConsumerWidget {
  final Profile profile;
  final List<HistoryItem> history;
  const _StatsRow({required this.profile, required this.history});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final accuracy = history.isEmpty ? 0 : history.map((h) => h.accuracy).reduce((a, b) => a + b) ~/ history.length;
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      child: Row(children: [
        _Stat(
          icon: Icons.local_fire_department_rounded,
          colors: AppGradients.fire,
          value: profile.currentStreak,
          label: s['stat_streak'],
          pulse: profile.currentStreak > 0,
        ),
        _divider(context),
        _Stat(icon: Icons.star_rounded, colors: AppGradients.gold, value: profile.totalPoints, label: s['stat_points']),
        _divider(context),
        _Stat(icon: Icons.task_alt_rounded, colors: AppGradients.mint, value: history.length, label: s['stat_tests']),
        _divider(context),
        _Stat(icon: Icons.track_changes_rounded, colors: AppGradients.sky, value: accuracy, suffix: '%',
            label: s['stat_accuracy']),
      ]),
    );
  }

  Widget _divider(BuildContext context) =>
      Container(width: 1, height: 44, color: Theme.of(context).dividerTheme.color);
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final List<Color> colors;
  final int value;
  final String label;
  final String suffix;
  final bool pulse;
  const _Stat({
    required this.icon,
    required this.colors,
    required this.value,
    required this.label,
    this.suffix = '',
    this.pulse = false,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Pulse(enabled: pulse, amplitude: 0.12, child: IconBadge(icon, colors: colors, size: 36)),
          const SizedBox(height: 8),
          FittedBox(
            child: CountUp(value, suffix: suffix, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          ),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: mutedOf(context), fontWeight: FontWeight.w600)),
        ]),
      );
}

/// Five levels as a path: passed ones are filled, the current one pulses, the progress bar shows the way to the next.
class _LevelPath extends ConsumerWidget {
  final Profile profile;
  const _LevelPath({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final palette = BranchPalette.of(ref.watch(branchProvider));
    final current = _levelCodes.indexOf(profile.level.code).clamp(0, _levelCodes.length - 1);
    final next = profile.level.nextCode;
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconBadge(Icons.route_rounded, colors: palette.gradient, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s['levels_path'], style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              Text(
                next == null
                    ? s['max_level']
                    : s.f('to_next_level',
                        {'level': s.level(next), 'n': (profile.level.nextLevelPoints ?? 0) - profile.totalPoints}),
                style: TextStyle(color: mutedOf(context), fontSize: 13),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 18),
        SizedBox(
          height: 64,
          child: LayoutBuilder(builder: (context, box) {
            final step = box.maxWidth / _levelCodes.length;
            return Stack(children: [
              Positioned(
                left: step / 2,
                right: step / 2,
                top: 15,
                child: GradientBar(
                  value: (current + profile.level.progress) / (_levelCodes.length - 1),
                  colors: palette.gradient,
                  height: 6,
                ),
              ),
              Row(children: [
                for (var i = 0; i < _levelCodes.length; i++)
                  SizedBox(
                    width: step,
                    child: Column(children: [
                      _LevelDot(index: i, reached: i <= current, current: i == current, colors: palette.gradient),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(s.level(_levelCodes[i]),
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: i == current ? FontWeight.w900 : FontWeight.w600,
                            color: i == current ? palette.primary : mutedOf(context),
                          )),
                      ),
                    ]),
                  ),
              ]),
            ]);
          }),
        ),
      ]),
    );
  }
}

class _LevelDot extends StatelessWidget {
  final int index;
  final bool reached;
  final bool current;
  final List<Color> colors;
  const _LevelDot({required this.index, required this.reached, required this.current, required this.colors});

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: reached ? AppGradients.of(colors) : null,
        color: reached ? null : surfaceOf(context),
        border: Border.all(
          color: reached ? Colors.white : Theme.of(context).colorScheme.outlineVariant,
          width: current ? 3 : 2,
        ),
        boxShadow: current ? [BoxShadow(color: colors.first.withValues(alpha: 0.5), blurRadius: 12)] : null,
      ),
      child: reached && !current
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
          : Text('${index + 1}',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: reached ? Colors.white : mutedOf(context),
              )),
    );
    return current ? Pulse(amplitude: 0.1, child: dot) : dot;
  }
}

/// Tests per day for the last 7 days, from the history.
class _WeekActivity extends ConsumerWidget {
  final List<HistoryItem> history;
  const _WeekActivity({required this.history});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final today = DateUtils.dateOnly(DateTime.now());
    final days = [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
    final counts = [
      for (final d in days)
        history.where((h) => h.finishedAt != null && DateUtils.isSameDay(h.finishedAt!.toLocal(), d)).length,
    ];
    final week = history.where((h) => h.finishedAt != null && !h.finishedAt!.toLocal().isBefore(days.first)).toList();
    final accuracy = week.isEmpty ? 0 : week.map((h) => h.accuracy).reduce((a, b) => a + b) ~/ week.length;
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const IconBadge(Icons.insights_rounded, colors: AppGradients.mint, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s['week_activity'], style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              Text(week.isEmpty ? s['week_empty'] : s.f('week_summary', {'n': week.length, 'a': accuracy}),
                  style: TextStyle(color: mutedOf(context), fontSize: 13)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        WeekBars(
          values: counts,
          labels: [for (final d in days) s['day_${d.weekday - 1}']],
          colors: AppGradients.mint,
          height: 90,
        ),
      ]),
    );
  }
}

class _ProgressTab extends ConsumerWidget {
  const _ProgressTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return ref.watch(progressProvider).when(
          loading: () => const Column(children: [Skeleton(height: 96, radius: 24), SizedBox(height: 12),
            Skeleton(height: 96, radius: 24)]),
          error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(progressProvider)),
          data: (list) => list.isEmpty
              ? EmptyState(icon: Icons.menu_book_rounded, text: s['no_subjects'])
              : Column(children: [
                  for (final (i, p) in list.indexed)
                    FadeSlideIn(
                      delay: Stagger.of(i, stepMs: 70),
                      child: Padding(padding: const EdgeInsets.only(bottom: 12), child: _SubjectProgressCard(p: p)),
                    ),
                ]),
        );
  }
}

class _SubjectProgressCard extends ConsumerWidget {
  final SubjectProgress p;
  const _SubjectProgressCard({required this.p});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final color = parseHexColor(p.color) ?? Theme.of(context).colorScheme.primary;
    final colors = AppGradients.fromColor(color);
    return AppCard(
      onTap: () => context.push('/subject/${p.subjectId}'),
      child: Row(children: [
        ProgressRing(
          value: p.percent / 100,
          size: 64,
          stroke: 7,
          colors: colors,
          child: Text('${p.percent}%', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 10),
            _Metric(label: s['material'], value: p.percent, colors: colors),
            const SizedBox(height: 6),
            _Metric(label: s['accuracy'], value: p.accuracy, colors: AppGradients.mint),
          ]),
        ),
        const SizedBox(width: 6),
        Icon(Icons.chevron_right_rounded, color: mutedOf(context)),
      ]),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final int value;
  final List<Color> colors;
  const _Metric({required this.label, required this.value, required this.colors});

  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(
          width: 78,
          child: Text(label, style: TextStyle(fontSize: 12, color: mutedOf(context), fontWeight: FontWeight.w600)),
        ),
        Expanded(child: GradientBar(value: value / 100, colors: colors, height: 7)),
        SizedBox(
          width: 42,
          child: Text('$value%',
              textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        ),
      ]);
}

class _AchievementsTab extends ConsumerWidget {
  const _AchievementsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return ref.watch(achievementsProvider).when(
          loading: () => const Skeleton(height: 220, radius: 24),
          error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(achievementsProvider)),
          data: (list) {
            final unlocked = list.where((a) => a.unlocked).length;
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  const IconBadge(Icons.emoji_events_rounded, colors: AppGradients.gold, size: 44),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.f('achievements_count', {'n': unlocked, 'total': list.length}),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      const SizedBox(height: 8),
                      GradientBar(value: list.isEmpty ? 0 : unlocked / list.length, colors: AppGradients.gold, height: 8),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.82,
                children: [
                  for (final (i, a) in list.indexed)
                    FadeSlideIn(
                      delay: Stagger.of(i, stepMs: 60),
                      scale: true,
                      child: _AchievementTile(a: a),
                    ),
                ],
              ),
            ]);
          },
        );
  }
}

class _AchievementTile extends StatelessWidget {
  final AchievementInfo a;
  const _AchievementTile({required this.a});

  @override
  Widget build(BuildContext context) {
    final colors = a.unlocked ? achievementColors(a.icon) : AppGradients.silver;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 10),
      onTap: () => showAchievementSheet(context, a),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Shine(
          enabled: a.unlocked,
          borderRadius: BorderRadius.circular(20),
          period: const Duration(milliseconds: 4200),
          child: IconBadge(a.unlocked ? achievementIcon(a.icon) : Icons.lock_rounded,
              colors: colors, size: 56, glow: a.unlocked),
        ),
        const SizedBox(height: 10),
        Text(a.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: a.unlocked ? null : mutedOf(context),
            )),
      ]),
    );
  }
}

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return ref.watch(historyProvider).when(
          loading: () => const Skeleton(height: 200, radius: 24),
          error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(historyProvider)),
          data: (list) => list.isEmpty
              ? EmptyState(icon: Icons.history_rounded, text: s['history_empty'], colors: AppGradients.violet)
              : Column(children: [
                  for (final (i, h) in list.indexed)
                    FadeSlideIn(
                      delay: Stagger.of(i, stepMs: 50),
                      child: Padding(padding: const EdgeInsets.only(bottom: 10), child: _HistoryTile(item: h)),
                    ),
                ]),
        );
  }
}

class _HistoryTile extends ConsumerWidget {
  final HistoryItem item;
  const _HistoryTile({required this.item});

  String _when(Strings s, DateTime? date) {
    if (date == null) return '';
    final days = DateUtils.dateOnly(DateTime.now()).difference(DateUtils.dateOnly(date.toLocal())).inDays;
    return switch (days) {
      0 => s['today'],
      1 => s['yesterday'],
      _ => s.f('days_ago', {'n': days}),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final colors = item.accuracy >= 80
        ? AppGradients.mint
        : (item.accuracy >= 50 ? AppGradients.gold : AppGradients.rose);
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: () => context.push('/result/${item.id}'),
      child: Row(children: [
        ProgressRing(
          value: item.accuracy / 100,
          size: 54,
          stroke: 6,
          colors: colors,
          child: Text(item.mmtScore != null ? '${item.mmtScore}' : '${item.accuracy}%',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: colors.last)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.title,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text('${s['test_type_${item.testType}']} · ${item.correctCount}/${item.totalCount} · ${_when(s, item.finishedAt)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: mutedOf(context), fontSize: 12.5)),
          ]),
        ),
        const SizedBox(width: 8),
        Pill('+${item.score}', icon: Icons.star_rounded, color: AppColors.gold),
      ]),
    );
  }
}

/// Gradient of an achievement badge by its icon.
List<Color> achievementColors(String? icon) => switch (icon) {
      'fire' => AppGradients.fire,
      'crown' || 'trophy' => AppGradients.gold,
      'gem' => AppGradients.violet,
      'star' => AppGradients.gold,
      'graduation' => AppGradients.sky,
      'flag' => AppGradients.mint,
      _ => AppGradients.rose,
    };
