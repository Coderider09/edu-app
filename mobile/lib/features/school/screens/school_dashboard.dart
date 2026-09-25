import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models.dart';
import '../../home/home_screen.dart';
import '../../offline/downloads_screen.dart';

/// Schoolboy home: subjects of the grade with progress.
class SchoolDashboard extends ConsumerWidget {
  const SchoolDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final dashboard = ref.watch(dashboardProvider);

    Future<void> refresh() async {
      ref.invalidate(dashboardProvider);
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
              DashboardHeader(data: data, subtitle: s.f('grade_n', {'n': data.grade ?? ''})),
              const OfflinePromoCard(),
              if (data.unfinished != null) ContinueTestCard(attempt: data.unfinished!),
              SectionTitle(s['subjects']),
              if (data.subjects.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(s['no_subjects'], textAlign: TextAlign.center),
                )
              else
                SubjectGrid(
                  subjects: data.subjects,
                  onOpen: (subject) => openAndRefresh(context, ref, '/subject/${subject.id}'),
                ),
              const SizedBox(height: 16),
              const MistakesCard(),
            ]),
          ),
        ),
      ),
    );
  }
}
