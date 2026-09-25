import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/ui.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../abiturient/screens/abiturient_dashboard.dart';
import '../../offline/sync_service.dart';
import '../auth/session_controller.dart';
import '../school/screens/school_dashboard.dart';

final dashboardProvider = FutureProvider.autoDispose<Dashboard>((ref) {
  // Reload when the active role or the content language changes
  ref.watch(sessionProvider.select((s) => (s.profile?.activeRole, s.profile?.language)));
  ref.watch(syncTickProvider); // offline results were uploaded
  return ref.watch(contentRepositoryProvider).dashboard();
});

/// Opens a screen and refreshes the dashboard/profile when the user comes back.
Future<void> openAndRefresh(BuildContext context, WidgetRef ref, String location) async {
  await context.push(location);
  ref.invalidate(dashboardProvider);
  ref.read(sessionProvider.notifier).refreshProfile();
}

/// Home tab: the dashboard of the active branch.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAbiturient = ref.watch(sessionProvider.select((s) => s.profile?.isAbiturient ?? false));
    return isAbiturient ? const AbiturientDashboard() : const SchoolDashboard();
  }
}

/// Greeting card: living gradient, avatar in the level ring, burning streak, points counting up.
class DashboardHeader extends ConsumerWidget {
  final Dashboard data;
  final String subtitle;
  const DashboardHeader({super.key, required this.data, required this.subtitle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final p = data.profile;
    final palette = BranchPalette.of(ref.watch(branchProvider));
    final next = p.level.nextCode;
    final white70 = Colors.white.withValues(alpha: 0.85);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.xl),
        boxShadow: [BoxShadow(color: palette.primary.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 12))],
      ),
      child: AuroraBackground(
        colors: palette.gradient,
        borderRadius: BorderRadius.circular(Radii.xl),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Pressable(
                onTap: () => context.go('/profile'),
                child: Hero(
                  tag: 'avatar-home', // the profile tab (same route) uses 'avatar'
                  child: RingAvatar(
                    avatarId: p.avatarId,
                    progress: p.level.progress,
                    size: 60,
                    colors: const [Color(0xFFFFE08A), Colors.white],
                    track: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.f('hello', {'name': p.name}),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: white70)),
                ]),
              ),
              const SizedBox(width: 8),
              _StreakBadge(days: p.currentStreak),
            ]),
            const SizedBox(height: 22),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              CountUp(p.totalPoints,
                  style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, height: 1)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(s['points'], style: TextStyle(color: white70, fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              if (data.rank != null) Pill('#${data.rank}', icon: Icons.emoji_events_rounded, onDark: true),
            ]),
            const SizedBox(height: 14),
            GradientBar(
              value: p.level.progress,
              colors: const [Color(0xFFFFE08A), Colors.white],
              track: Colors.white.withValues(alpha: 0.22),
              height: 10,
            ),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text('${s['level']} ${p.level.number} · ${s.level(p.level.code)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: 2),
            Text(
              next == null
                  ? s['max_level']
                  : s.f('to_next_level', {'level': s.level(next), 'n': (p.level.nextLevelPoints ?? 0) - p.totalPoints}),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: white70, fontSize: 12.5),
            ),
          ]),
        ),
      ),
    );
  }
}

class _StreakBadge extends ConsumerWidget {
  final int days;
  const _StreakBadge({required this.days});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Tooltip(
      message: days > 0 ? s['keep_streak'] : s['start_streak'],
      triggerMode: TooltipTriggerMode.tap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Pulse(
            enabled: days > 0,
            amplitude: 0.16,
            period: const Duration(milliseconds: 900),
            child: ShaderMask(
              shaderCallback: (r) => AppGradients.of(days > 0 ? AppGradients.fire : AppGradients.silver,
                  begin: Alignment.bottomCenter, end: Alignment.topCenter).createShader(r),
              child: const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(width: 2),
          Text('$days', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF1E2230))),
        ]),
      ),
    );
  }
}

/// Round shortcuts under the header.
class QuickActions extends ConsumerWidget {
  final bool abiturient;
  final int? clusterId;
  const QuickActions({super.key, required this.abiturient, this.clusterId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final actions = [
      if (abiturient && clusterId != null)
        (Icons.assignment_rounded, AppGradients.violet, s['qa_mock'],
            () => openAndRefresh(context, ref, '/test/mock_exam?ref=$clusterId&title=${Uri.encodeComponent(s['mock_exam'])}')),
      (Icons.replay_rounded, AppGradients.rose, s['qa_mistakes'],
          () => openAndRefresh(context, ref, '/test/mistakes?title=${Uri.encodeComponent(s['repeat_mistakes'])}')),
      (Icons.leaderboard_rounded, AppGradients.gold, s['qa_rating'], () => context.go('/rating')),
      (Icons.download_for_offline_rounded, AppGradients.mint, s['qa_offline'], () => context.push('/downloads')),
      if (!abiturient) (Icons.settings_rounded, AppGradients.sky, s['qa_settings'], () => context.push('/settings')),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(children: [
        for (final (i, (icon, colors, label, onTap)) in actions.indexed)
          Expanded(
            child: FadeSlideIn(
              delay: Stagger.of(i, stepMs: 70, startMs: 150),
              scale: true,
              child: Pressable(
                onTap: onTap,
                pressedScale: 0.9,
                child: Column(children: [
                  IconBadge(icon, colors: colors, size: 56),
                  const SizedBox(height: 8),
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Card of a subject: gradient icon, progress ring, subtest label.
class SubjectCard extends ConsumerWidget {
  final Subject subject;
  final VoidCallback onTap;
  const SubjectCard({super.key, required this.subject, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final color = parseHexColor(subject.color) ?? Theme.of(context).colorScheme.primary;
    final colors = AppGradients.fromColor(color);
    final percent = subject.progressPercent ?? 0;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Hero(tag: 'subject-${subject.id}', child: IconBadge(subjectIcon(subject.icon), colors: colors, size: 50)),
          const Spacer(),
          ProgressRing(
            value: percent / 100,
            size: 44,
            stroke: 5,
            colors: colors,
            child: Text('$percent', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900)),
          ),
        ]),
        const Spacer(),
        if (subject.position != null) ...[
          Text(s.f('subtest_n', {'n': subject.position!}),
              style: TextStyle(color: colors.last, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          const SizedBox(height: 2),
        ],
        Text(subject.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, height: 1.2)),
      ]),
    );
  }
}

class SubjectGrid extends StatelessWidget {
  final List<Subject> subjects;
  final void Function(Subject) onOpen;
  const SubjectGrid({super.key, required this.subjects, required this.onOpen});

  @override
  Widget build(BuildContext context) => GridView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.02,
        ),
        itemCount: subjects.length,
        itemBuilder: (context, i) => FadeSlideIn(
          delay: Stagger.of(i, stepMs: 80, startMs: 200),
          child: SubjectCard(subject: subjects[i], onTap: () => onOpen(subjects[i])),
        ),
      );
}

/// "Continue test" card for an unfinished attempt: progress and a pulsing play button.
class ContinueTestCard extends ConsumerWidget {
  final AttemptBrief attempt;
  const ContinueTestCard({super.key, required this.attempt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final palette = BranchPalette.of(ref.watch(branchProvider));
    final total = attempt.totalCount == 0 ? 1 : attempt.totalCount;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: FadeSlideIn(
        delay: const Duration(milliseconds: 250),
        child: AppCard(
          shadowColor: palette.primary,
          onTap: () => openAndRefresh(
            context,
            ref,
            '/test/${attempt.testType}?${attempt.referenceId != null ? 'ref=${attempt.referenceId}&' : ''}'
            'title=${Uri.encodeComponent(attempt.title)}',
          ),
          child: Row(children: [
            Pulse(
              amplitude: 0.07,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppGradients.of(palette.gradient),
                  boxShadow: [BoxShadow(color: palette.primary.withValues(alpha: 0.45), blurRadius: 16)],
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s['continue_test'], style: TextStyle(color: palette.primary, fontWeight: FontWeight.w900, fontSize: 13)),
                Text(attempt.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 8),
                GradientBar(value: attempt.answeredCount / total, colors: palette.gradient, height: 7),
                const SizedBox(height: 4),
                Text(s.f('answered_of', {'a': attempt.answeredCount, 't': attempt.totalCount}),
                    style: TextStyle(color: mutedOf(context), fontSize: 12)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class MistakesCard extends ConsumerWidget {
  const MistakesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return AppCard(
      onTap: () => openAndRefresh(context, ref, '/test/mistakes?title=${Uri.encodeComponent(s['repeat_mistakes'])}'),
      child: Row(children: [
        const IconBadge(Icons.replay_rounded, colors: AppGradients.rose, size: 48),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s['repeat_mistakes'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            Text(s['repeat_mistakes_desc'], style: TextStyle(color: mutedOf(context), fontSize: 13)),
          ]),
        ),
        Icon(Icons.arrow_forward_ios_rounded, size: 16, color: mutedOf(context)),
      ]),
    );
  }
}

/// Skeleton layout of a dashboard.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          Skeleton(height: 210, radius: 32),
          SizedBox(height: 24),
          Row(children: [
            Expanded(child: Skeleton(height: 76, radius: 20)),
            SizedBox(width: 12),
            Expanded(child: Skeleton(height: 76, radius: 20)),
            SizedBox(width: 12),
            Expanded(child: Skeleton(height: 76, radius: 20)),
            SizedBox(width: 12),
            Expanded(child: Skeleton(height: 76, radius: 20)),
          ]),
          SizedBox(height: 28),
          Skeleton(height: 24, width: 160),
          SizedBox(height: 14),
          Row(children: [
            Expanded(child: Skeleton(height: 160, radius: 24)),
            SizedBox(width: 14),
            Expanded(child: Skeleton(height: 160, radius: 24)),
          ]),
        ],
      );
}
