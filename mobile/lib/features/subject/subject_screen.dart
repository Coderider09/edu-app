import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
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
      appBar: AppBar(title: Text(tree.valueOrNull?.subject.title ?? '')),
      body: AsyncBody<SubjectTree>(
        value: tree,
        onRetry: () => ref.invalidate(subjectTreeProvider(subjectId)),
        builder: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(subjectTreeProvider(subjectId)),
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
            _SubjectHeader(subject: data.subject),
            const SizedBox(height: 12),
            TapCard(
              onTap: () => open(
                  '/test/practice?ref=${data.subject.id}&title=${Uri.encodeComponent('${s['practice']}: ${data.subject.title}')}'),
              child: Row(children: [
                const Icon(Icons.fitness_center_rounded, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s['practice'], style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(s['practice_desc'], style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded),
              ]),
            ),
            for (final section in data.sections) ...[
              SectionTitle(
                section.title,
                trailing: Text('${section.progress.percent}%', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              for (final topic in section.topics)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TopicTile(topic: topic, onOpen: open),
                ),
              if (section.hasFinalTest)
                TapCard(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  onTap: () => open('/test/section_test?ref=${section.id}&title=${Uri.encodeComponent(section.title)}'),
                  child: Row(children: [
                    const Icon(Icons.flag_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(s['section_final_test'], style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ]),
                ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _SubjectHeader extends StatelessWidget {
  final Subject subject;
  const _SubjectHeader({required this.subject});

  @override
  Widget build(BuildContext context) {
    final color = parseHexColor(subject.color) ?? Theme.of(context).colorScheme.primary;
    final percent = subject.progressPercent ?? 0;
    return Row(children: [
      Hero(
        tag: 'subject-${subject.id}',
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
          child: Icon(subjectIcon(subject.icon), color: color, size: 32),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$percent%', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          AnimatedProgressBar(value: percent / 100, color: color),
        ]),
      ),
    ]);
  }
}

class _TopicTile extends ConsumerWidget {
  final Topic topic;
  final Future<void> Function(String location) onOpen;
  const _TopicTile({required this.topic, required this.onOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = topic.progress;
    final scheme = Theme.of(context).colorScheme;
    return TapCard(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _TopicSheet(topic: topic, onOpen: onOpen),
      ),
      child: Row(children: [
        SizedBox(
          width: 44,
          height: 44,
          child: Stack(alignment: Alignment.center, children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: p.percent / 100),
              duration: const Duration(milliseconds: 800),
              builder: (context, v, _) => CircularProgressIndicator(
                value: v,
                strokeWidth: 4,
                backgroundColor: scheme.surfaceContainerHighest,
                color: p.passed ? AppColors.correct : scheme.primary,
              ),
            ),
            if (p.passed)
              const Icon(Icons.check_rounded, color: AppColors.correct, size: 22)
            else
              Text('${p.percent}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(topic.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Row(children: [
              if (p.lessonsTotal > 0) ...[
                Icon(Icons.menu_book_rounded, size: 14, color: scheme.outline),
                Text(' ${p.lessonsCompleted}/${p.lessonsTotal}   ', style: Theme.of(context).textTheme.bodySmall),
              ],
              if (p.questionsCount > 0) ...[
                Icon(Icons.quiz_rounded, size: 14, color: scheme.outline),
                Text(' ${p.bestAccuracy != null ? '${p.bestAccuracy}%' : p.questionsCount}',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ]),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded),
      ]),
    );
  }
}

class _TopicSheet extends ConsumerWidget {
  final Topic topic;
  final Future<void> Function(String location) onOpen;
  const _TopicSheet({required this.topic, required this.onOpen});

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
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, controller) => ListView(controller: controller, padding: const EdgeInsets.all(20), children: [
        Text(topic.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        SectionTitle(s['lessons']),
        lessons.when(
          loading: () => const Skeleton(height: 64),
          error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(topicLessonsProvider(topic.id))),
          data: (list) => Column(children: [
            for (final lesson in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TapCard(
                  onTap: () => go('/lesson/${lesson.id}'),
                  child: Row(children: [
                    Icon(lesson.completed ? Icons.check_circle_rounded : Icons.play_lesson_rounded,
                        color: lesson.completed ? AppColors.correct : Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(child: Text(lesson.title, style: const TextStyle(fontWeight: FontWeight.w600))),
                    const Icon(Icons.chevron_right_rounded),
                  ]),
                ),
              ),
          ]),
        ),
        tests.maybeWhen(
          data: (list) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final test in list) ...[
              SectionTitle(s['topic_test']),
              Text(s.f('questions_n', {'n': test.defaultQuestionCount}) +
                  (test.bestAccuracy != null ? ' · ${s.f('best_result', {'n': test.bestAccuracy!})}' : '')),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(s['without_timer']),
                onPressed: () => go('/test/topic_test?ref=${test.topicId}&title=${Uri.encodeComponent(test.title)}'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.timer_outlined),
                label: Text(s['with_timer']),
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
