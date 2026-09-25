import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/strings.dart';
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
        child: AsyncBody<Dashboard>(
          value: dashboard,
          onRetry: refresh,
          loading: const DashboardSkeleton(),
          builder: (data) => RefreshIndicator(
            onRefresh: refresh,
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 32), children: [
              if (data.fromCache) const Padding(padding: EdgeInsets.only(bottom: 12), child: OfflineBanner()),
              DashboardHeader(data: data, subtitle: data.clusterTitle ?? s['your_cluster']),
              const OfflinePromoCard(),
              if (data.unfinished != null) ContinueTestCard(attempt: data.unfinished!),
              SectionTitle(s['subjects']),
              SubjectGrid(
                subjects: data.subjects,
                onOpen: (subject) => openAndRefresh(context, ref, '/subject/${subject.id}'),
              ),
              SectionTitle(s['exam_prep']),
              if (cluster != null)
                cluster.when(
                  loading: () => const Skeleton(height: 140, radius: 20),
                  error: (e, _) => const SizedBox.shrink(),
                  data: (c) => Column(children: [
                    if (c.mockExam != null) _MockExamCard(info: c.mockExam!),
                    for (final exam in c.examTests)
                      Padding(padding: const EdgeInsets.only(top: 10), child: _ExamCard(exam: exam)),
                  ]),
                ),
              const SizedBox(height: 8),
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
    final scheme = Theme.of(context).colorScheme;
    return TapCard(
      onTap: () => openAndRefresh(
          context, ref, '/test/exam_test?ref=${exam.id}&title=${Uri.encodeComponent(exam.title)}'),
      child: Row(children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [scheme.primary, scheme.secondary]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text('${exam.year}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(exam.title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(s.f('exam_minutes', {'n': exam.durationMinutes, 'q': exam.totalQuestions}),
                style: Theme.of(context).textTheme.bodySmall),
            if (exam.bestMmtScore != null)
              Text(s.f('best_mmt', {'n': exam.bestMmtScore!}),
                  style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
        ),
        Icon(Icons.timer_outlined, color: scheme.primary),
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
    final scheme = Theme.of(context).colorScheme;
    return Material(
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(gradient: LinearGradient(colors: [scheme.primary, scheme.secondary])),
        child: InkWell(
          onTap: () => openAndRefresh(
              context, ref, '/test/mock_exam?ref=${info.clusterId}&title=${Uri.encodeComponent(s['mock_exam'])}'),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.assignment_rounded, color: Colors.white, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(s['mock_exam'],
                      style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
                ),
                const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 34),
              ]),
              const SizedBox(height: 6),
              Text(
                s.f('mock_exam_desc', {'q': info.questions, 'min': info.durationMinutes, 'max': info.maxScore}),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
              ),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final st in info.subtests)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                    child: Text('A${st.position} ${st.title} · ${st.maxScore}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
