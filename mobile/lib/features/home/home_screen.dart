import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../abiturient/screens/abiturient_dashboard.dart';
import '../auth/session_controller.dart';
import '../school/screens/school_dashboard.dart';

final dashboardProvider = FutureProvider.autoDispose<Dashboard>((ref) {
  // Reload when the active role or the content language changes
  ref.watch(sessionProvider.select((s) => (s.profile?.activeRole, s.profile?.language)));
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

/// Greeting card with avatar, points, level progress and daily streak.
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(colors: palette.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: palette.primary.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          AvatarCircle(p.avatarId, size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.f('hello', {'name': p.name}),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
            ]),
          ),
          _StreakBadge(days: p.currentStreak),
        ]),
        const SizedBox(height: 20),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          CountUp(p.totalPoints,
              style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(s['points'], style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
            child: Text('${s['level']} ${p.level.number} · ${s.level(p.level.code)}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 10),
        AnimatedProgressBar(value: p.level.progress, color: Colors.white, height: 8),
        const SizedBox(height: 6),
        Text(
          next == null
              ? s['max_level']
              : s.f('to_next_level', {'level': s.level(next), 'n': (p.level.nextLevelPoints ?? 0) - p.totalPoints}),
          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
        ),
        if (data.rank != null) ...[
          const SizedBox(height: 4),
          Text(s.f('rank_n', {'n': data.rank!}),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
        ],
      ]),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  final int days;
  const _StreakBadge({required this.days});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.local_fire_department_rounded,
              color: days > 0 ? AppColors.streak : Colors.grey, size: 22),
          const SizedBox(width: 2),
          Text('$days', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black87)),
        ]),
      );
}

/// Card of a subject with its progress.
class SubjectCard extends ConsumerWidget {
  final Subject subject;
  final VoidCallback onTap;
  const SubjectCard({super.key, required this.subject, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = parseHexColor(subject.color) ?? Theme.of(context).colorScheme.primary;
    final percent = subject.progressPercent ?? 0;
    return TapCard(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
          child: Icon(subjectIcon(subject.icon), color: color, size: 28),
        ),
        const Spacer(),
        Text(subject.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: AnimatedProgressBar(value: percent / 100, color: color, height: 6)),
          const SizedBox(width: 8),
          Text('$percent%', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        ]),
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
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.05,
        ),
        itemCount: subjects.length,
        itemBuilder: (context, i) => TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 350 + 80 * i),
          curve: Curves.easeOutCubic,
          builder: (context, v, child) =>
              Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 24 * (1 - v)), child: child)),
          child: SubjectCard(subject: subjects[i], onTap: () => onOpen(subjects[i])),
        ),
      );
}

/// "Continue test" card for an unfinished attempt.
class ContinueTestCard extends ConsumerWidget {
  final AttemptBrief attempt;
  const ContinueTestCard({super.key, required this.attempt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final scheme = Theme.of(context).colorScheme;
    final total = attempt.totalCount == 0 ? 1 : attempt.totalCount;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: TapCard(
        color: scheme.primaryContainer,
        onTap: () => openAndRefresh(
          context,
          ref,
          '/test/${attempt.testType}?${attempt.referenceId != null ? 'ref=${attempt.referenceId}&' : ''}'
          'title=${Uri.encodeComponent(attempt.title)}',
        ),
        child: Row(children: [
          Icon(Icons.play_circle_fill_rounded, size: 44, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s['continue_test'], style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(attempt.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              AnimatedProgressBar(value: attempt.answeredCount / total, height: 6),
            ]),
          ),
        ]),
      ),
    );
  }
}

class MistakesCard extends ConsumerWidget {
  const MistakesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return TapCard(
      onTap: () => openAndRefresh(context, ref, '/test/mistakes?title=${Uri.encodeComponent(s['repeat_mistakes'])}'),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.wrong.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.replay_rounded, color: AppColors.wrong),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s['repeat_mistakes'], style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(s['repeat_mistakes_desc'], style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded),
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
          Skeleton(height: 190, radius: 24),
          SizedBox(height: 28),
          Skeleton(height: 24, width: 160),
          SizedBox(height: 12),
          Row(children: [
            Expanded(child: Skeleton(height: 150, radius: 16)),
            SizedBox(width: 12),
            Expanded(child: Skeleton(height: 150, radius: 16)),
          ]),
          SizedBox(height: 12),
          Skeleton(height: 80, radius: 16),
        ],
      );
}
