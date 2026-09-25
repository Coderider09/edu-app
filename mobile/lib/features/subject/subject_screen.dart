import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/ui.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../home/home_screen.dart';

final subjectTreeProvider =
    FutureProvider.autoDispose.family<SubjectTree, int>((ref, id) => ref.watch(contentRepositoryProvider).subjectTree(id));

final topicLessonsProvider =
    FutureProvider.autoDispose.family<List<Lesson>, int>((ref, id) => ref.watch(contentRepositoryProvider).lessons(id));

final topicTestsProvider = FutureProvider.autoDispose
    .family<List<TopicTestInfo>, int>((ref, id) => ref.watch(contentRepositoryProvider).topicTests(id));

/// Subject → sections (раздел / четверть) → topics → lessons and tests.
class SubjectScreen extends ConsumerWidget {
  final int subjectId;
  const SubjectScreen({super.key, required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final tree = ref.watch(subjectTreeProvider(subjectId));

    Future<void> open(String location) async {
      await openAndRefresh(context, ref, location);
      ref.invalidate(subjectTreeProvider(subjectId));
    }

    return Scaffold(
      body: AsyncBody<SubjectTree>(
        value: tree,
        onRetry: () => ref.invalidate(subjectTreeProvider(subjectId)),
        builder: (data) {
          final color = parseHexColor(data.subject.color) ?? Theme.of(context).colorScheme.primary;
          final colors = AppGradients.fromColor(color);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(subjectTreeProvider(subjectId)),
            edgeOffset: 120,
            child: CustomScrollView(slivers: [
              SliverToBoxAdapter(child: _SubjectHeader(subject: data.subject, colors: colors)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                sliver: SliverList.list(children: [
                  FadeSlideIn(
                    child: AppCard(
                      onTap: () => open('/test/practice?ref=${data.subject.id}'
                          '&title=${Uri.encodeComponent('${s['practice']}: ${data.subject.title}')}'),
                      child: Row(children: [
                        IconBadge(Icons.fitness_center_rounded, colors: colors, size: 50),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s['practice'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                            Text(s['practice_desc'], style: TextStyle(color: mutedOf(context), fontSize: 13)),
                          ]),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, size: 16, color: mutedOf(context)),
                      ]),
                    ),
                  ),
                  for (final section in data.sections) ...[
                    SectionHeader(
                      section.title,
                      trailing: Pill('${section.progress.percent}%', color: colors.last),
                    ),
                    for (final (i, topic) in section.topics.indexed)
                      FadeSlideIn(
                        delay: Stagger.of(i, stepMs: 50),
                        child: _TopicTile(
                          topic: topic,
                          colors: colors,
                          first: i == 0,
                          last: i == section.topics.length - 1 && !section.hasFinalTest,
                          onOpen: open,
                        ),
                      ),
                    if (section.hasFinalTest)
                      AppCard(
                        gradient: AppGradients.of(colors),
                        shadowColor: colors.last,
                        onTap: () => open('/test/section_test?ref=${section.id}&title=${Uri.encodeComponent(section.title)}'),
                        child: Row(children: [
                          const Icon(Icons.flag_rounded, color: Colors.white, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(s['section_final_test'],
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                          ),
                          const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 32),
                        ]),
                      ),
                  ],
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _SubjectHeader extends StatelessWidget {
  final Subject subject;
  final List<Color> colors;
  const _SubjectHeader({required this.subject, required this.colors});

  @override
  Widget build(BuildContext context) {
    final percent = subject.progressPercent ?? 0;
    return AuroraBackground(
      colors: colors,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 20, 26),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GlassIconButton(icon: Icons.arrow_back_rounded, onPressed: () => Navigator.of(context).maybePop()),
            const SizedBox(height: 16),
            Row(children: [
              const SizedBox(width: 4),
              Hero(
                tag: 'subject-${subject.id}',
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                  ),
                  child: Icon(subjectIcon(subject.icon), color: Colors.white, size: 40),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(subject.title,
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, height: 1.15)),
              ),
              ProgressRing(
                value: percent / 100,
                size: 72,
                stroke: 8,
                colors: const [Color(0xFFFFE08A), Colors.white],
                track: Colors.white.withValues(alpha: 0.25),
                child: Text('$percent%',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// A topic as a stop on a vertical path: ring with progress, connecting line, lessons and test info.
class _TopicTile extends ConsumerWidget {
  final Topic topic;
  final List<Color> colors;
  final bool first;
  final bool last;
  final Future<void> Function(String location) onOpen;
  const _TopicTile({
    required this.topic,
    required this.colors,
    required this.first,
    required this.last,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = topic.progress;
    final line = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1);
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 56,
          child: Stack(alignment: Alignment.center, children: [
            Column(children: [
              Expanded(child: Container(width: 3, color: first ? Colors.transparent : line)),
              Expanded(child: Container(width: 3, color: last ? Colors.transparent : line)),
            ]),
            ProgressRing(
              value: p.percent / 100,
              size: 48,
              stroke: 5,
              colors: p.passed ? AppGradients.mint : colors,
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: p.passed ? AppGradients.of(AppGradients.mint) : null,
                  color: p.passed ? null : surfaceOf(context),
                ),
                child: p.passed
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                    : Text('${p.percent}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
              ),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: AppCard(
              padding: const EdgeInsets.all(14),
              onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => _TopicSheet(topic: topic, colors: colors, onOpen: onOpen),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(topic.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 8, runSpacing: 4, children: [
                      if (p.lessonsTotal > 0)
                        _Meta(Icons.menu_book_rounded, '${p.lessonsCompleted}/${p.lessonsTotal}'),
                      if (p.questionsCount > 0)
                        _Meta(Icons.quiz_rounded, p.bestAccuracy != null ? '${p.bestAccuracy}%' : '${p.questionsCount}'),
                    ]),
                  ]),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 15, color: mutedOf(context)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: mutedOf(context)),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: mutedOf(context), fontSize: 12.5, fontWeight: FontWeight.w700)),
      ]);
}

class _TopicSheet extends ConsumerWidget {
  final Topic topic;
  final List<Color> colors;
  final Future<void> Function(String location) onOpen;
  const _TopicSheet({required this.topic, required this.colors, required this.onOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final lessons = ref.watch(topicLessonsProvider(topic.id));
    final tests = ref.watch(topicTestsProvider(topic.id));

    void go(String location) {
      Navigator.of(context).pop();
      onOpen(location);
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      maxChildSize: 0.92,
      builder: (context, controller) => ListView(controller: controller, padding: const EdgeInsets.fromLTRB(20, 0, 20, 28), children: [
        Row(children: [
          IconBadge(Icons.auto_stories_rounded, colors: colors, size: 48),
          const SizedBox(width: 14),
          Expanded(child: Text(topic.title, style: Theme.of(context).textTheme.titleLarge)),
        ]),
        SectionHeader(s['lessons']),
        lessons.when(
          loading: () => const Skeleton(height: 72, radius: 20),
          error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(topicLessonsProvider(topic.id))),
          data: (list) => Column(children: [
            for (final (i, lesson) in list.indexed)
              FadeSlideIn(
                delay: Stagger.of(i),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    padding: const EdgeInsets.all(14),
                    onTap: () => go('/lesson/${lesson.id}'),
                    child: Row(children: [
                      IconBadge(lesson.completed ? Icons.check_rounded : Icons.play_arrow_rounded,
                          colors: lesson.completed ? AppGradients.mint : colors, size: 40, glow: false),
                      const SizedBox(width: 12),
                      Expanded(child: Text(lesson.title, style: const TextStyle(fontWeight: FontWeight.w700))),
                      Icon(Icons.arrow_forward_ios_rounded, size: 15, color: mutedOf(context)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
        tests.maybeWhen(
          data: (list) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final test in list) ...[
              SectionHeader(
                s['topic_test'],
                subtitle: s.f('questions_n', {'n': test.defaultQuestionCount}),
                trailing: test.bestAccuracy != null
                    ? Pill(s.f('best_result', {'n': test.bestAccuracy!}), icon: Icons.emoji_events_rounded,
                        color: AppColors.gold)
                    : null,
              ),
              GradientButton(
                label: s['without_timer'],
                icon: Icons.play_arrow_rounded,
                colors: colors,
                onPressed: () => go('/test/topic_test?ref=${test.topicId}&title=${Uri.encodeComponent(test.title)}'),
              ),
              const SizedBox(height: 10),
              SoftButton(
                label: s['with_timer'],
                icon: Icons.timer_outlined,
                color: colors.last,
                onPressed: () =>
                    go('/test/topic_test?ref=${test.topicId}&timed=1&title=${Uri.encodeComponent(test.title)}'),
              ),
            ],
          ]),
          orElse: () => const SizedBox.shrink(),
        ),
      ]),
    );
  }
}
