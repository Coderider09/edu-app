import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models.dart';
import '../../../data/repositories.dart';
import '../../home/home_screen.dart';
import '../../offline/downloads_screen.dart';

final clusterScreenProvider = FutureProvider.autoDispose.family<ClusterScreenData, int>(
    (ref, clusterId) => ref.watch(contentRepositoryProvider).clusterScreen(clusterId));

/// Abiturient home = the screen of the chosen ЦВЭ cluster: subtests A1–A4, the full mock ЦВЭ,
/// official sample tests, mistakes, rating position.
class AbiturientDashboard extends ConsumerWidget {
  const AbiturientDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final dashboard = ref.watch(dashboardProvider);
    final clusterId = dashboard.valueOrNull?.clusterId;
    final cluster = clusterId == null ? null : ref.watch(clusterScreenProvider(clusterId));

    Future<void> refresh() async {
      ref.invalidate(dashboardProvider);
      if (clusterId != null) ref.invalidate(clusterScreenProvider(clusterId));
      await ref.read(dashboardProvider.future);
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AsyncBody<Dashboard>(
          value: dashboard,
          onRetry: refresh,
          loading: const DashboardSkeleton(),
          builder: (data) => RefreshIndicator(
            onRefresh: refresh,
            child: ListView(padding: Gap.page.copyWith(top: 12), children: [
              if (data.fromCache) const Padding(padding: EdgeInsets.only(bottom: 12), child: OfflineBanner()),
              FadeSlideIn(child: DashboardHeader(data: data, subtitle: data.clusterTitle ?? s['your_cluster'])),
              QuickActions(abiturient: true, clusterId: data.clusterId),
              if (data.unfinished != null) ContinueTestCard(attempt: data.unfinished!),
              const OfflinePromoCard(),
              SectionHeader(s['subjects']),
              SubjectGrid(
                subjects: data.subjects,
                onOpen: (subject) => openAndRefresh(context, ref, '/subject/${subject.id}'),
              ),
              SectionHeader(s['exam_prep']),
              if (cluster != null)
                cluster.when(
                  loading: () => const Skeleton(height: 180, radius: 28),
                  error: (e, _) => const SizedBox.shrink(),
                  data: (c) => Column(children: [
                    if (c.mockExam != null) FadeSlideIn(child: _MockExamCard(info: c.mockExam!)),
                    for (final (i, exam) in c.examTests.indexed)
                      FadeSlideIn(
                        delay: Stagger.of(i + 1),
                        child: Padding(padding: const EdgeInsets.only(top: 12), child: _ExamCard(exam: exam)),
                      ),
                  ]),
                ),
              const SizedBox(height: 12),
              const MistakesCard(),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ExamCard extends ConsumerWidget {
  final ExamTestInfo exam;
  const _ExamCard({required this.exam});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final palette = BranchPalette.of(ref.watch(branchProvider));
    return AppCard(
      onTap: () => openAndRefresh(
          context, ref, '/test/exam_test?ref=${exam.id}&title=${Uri.encodeComponent(exam.title)}'),
      child: Row(children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AppGradients.of(palette.gradient),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: palette.primary.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6))],
          ),
          child: Text('${exam.year}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(exam.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.timer_outlined, size: 15, color: mutedOf(context)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(s.f('exam_minutes', {'n': exam.durationMinutes, 'q': exam.totalQuestions}),
                    style: TextStyle(color: mutedOf(context), fontSize: 13)),
              ),
            ]),
            if (exam.bestMmtScore != null) ...[
              const SizedBox(height: 6),
              Pill(s.f('best_mmt', {'n': exam.bestMmtScore!}), icon: Icons.emoji_events_rounded, color: AppColors.gold),
            ],
          ]),
        ),
        Icon(Icons.arrow_forward_ios_rounded, size: 16, color: mutedOf(context)),
      ]),
    );
  }
}

/// Full ЦВЭ simulation generated from the official task bank: 4 subtests, official task counts and time.
class _MockExamCard extends ConsumerWidget {
  final MockExamInfo info;
  const _MockExamCard({required this.info});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    const colors = [Color(0xFF0F172A), Color(0xFF4338CA)];
    final radius = BorderRadius.circular(Radii.xl);
    return Pressable(
      onTap: () => openAndRefresh(
          context, ref, '/test/mock_exam?ref=${info.clusterId}&title=${Uri.encodeComponent(s['mock_exam'])}'),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [BoxShadow(color: colors.last.withValues(alpha: 0.4), blurRadius: 26, offset: const Offset(0, 12))],
        ),
        child: AuroraBackground(
          colors: colors,
          borderRadius: radius,
          child: Shine(
            borderRadius: radius,
            period: const Duration(milliseconds: 5000),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const IconBadge(Icons.assignment_rounded, colors: AppGradients.violet, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(s['mock_exam'],
                        style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                  ),
                  Pulse(
                    amplitude: 0.08,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                      child: Icon(Icons.play_arrow_rounded, color: colors.last, size: 32),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Text(
                  s.f('mock_exam_desc', {'q': info.questions, 'min': info.durationMinutes, 'max': info.maxScore}),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), height: 1.4),
                ),
                const SizedBox(height: 14),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final st in info.subtests)
                    Pill('A${st.position} · ${st.title} · ${st.maxScore}', onDark: true),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
