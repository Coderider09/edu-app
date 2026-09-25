import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/ui/ui.dart';
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
        bottom: false,
        child: AsyncBody<Dashboard>(
          value: dashboard,
          onRetry: refresh,
          loading: const DashboardSkeleton(),
          builder: (data) => RefreshIndicator(
            onRefresh: refresh,
            child: ListView(padding: Gap.page.copyWith(top: 12), children: [
              if (data.fromCache) const Padding(padding: EdgeInsets.only(bottom: 12), child: OfflineBanner()),
              FadeSlideIn(child: DashboardHeader(data: data, subtitle: s.f('grade_n', {'n': data.grade ?? ''}))),
              const QuickActions(abiturient: false),
              if (data.unfinished != null) ContinueTestCard(attempt: data.unfinished!),
              const OfflinePromoCard(),
              SectionHeader(s['subjects']),
              if (data.subjects.isEmpty)
                EmptyState(icon: Icons.menu_book_rounded, text: s['no_subjects'], colors: AppGradients.gold)
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
