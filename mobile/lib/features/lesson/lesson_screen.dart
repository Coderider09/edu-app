import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/markdown_view.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';

final lessonProvider =
    FutureProvider.autoDispose.family<Lesson, int>((ref, id) => ref.watch(contentRepositoryProvider).lesson(id));

/// Lesson: text + formulas/images, then a mini-check (3–5 questions). Cached for offline reading.
class LessonScreen extends ConsumerStatefulWidget {
  final int lessonId;
  const LessonScreen({super.key, required this.lessonId});

  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen> {
  bool _saving = false;
  final _scroll = ScrollController();
  double _readProgress = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final max = _scroll.position.maxScrollExtent;
      final v = max <= 0 ? 1.0 : (_scroll.offset / max).clamp(0.0, 1.0);
      if ((v - _readProgress).abs() > 0.01) setState(() => _readProgress = v);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    final s = ref.read(stringsProvider);
    setState(() => _saving = true);
    try {
      await ref.read(contentRepositoryProvider).completeLesson(widget.lessonId);
      HapticFeedback.lightImpact();
      ref.invalidate(lessonProvider(widget.lessonId));
    } catch (e) {
      if (mounted) showError(context, s, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final lesson = ref.watch(lessonProvider(widget.lessonId));
    return Scaffold(
      appBar: AppBar(
        title: Text(s['lesson']),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: _readProgress, minHeight: 4),
        ),
      ),
      body: AsyncBody<Lesson>(
        value: lesson,
        onRetry: () => ref.invalidate(lessonProvider(widget.lessonId)),
        loading: ListView(padding: const EdgeInsets.all(20), children: const [
          Skeleton(height: 32, width: 240),
          SizedBox(height: 20),
          Skeleton(height: 16),
          SizedBox(height: 10),
          Skeleton(height: 16),
          SizedBox(height: 10),
          Skeleton(height: 16, width: 200),
          SizedBox(height: 24),
          Skeleton(height: 140),
        ]),
        builder: (data) => ListView(controller: _scroll, padding: const EdgeInsets.fromLTRB(20, 16, 20, 40), children: [
          MarkdownView(data.content),
          for (final url in data.mediaUrls)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(url, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            ),
          if (data.videoUrl != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.ondemand_video_rounded),
                title: Text(s['video']),
                subtitle: SelectableText(data.videoUrl!),
              ),
            ),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: data.completed
                ? Container(
                    key: const ValueKey('done'),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.correct.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.correct),
                      const SizedBox(width: 8),
                      Text(s['lesson_done'], style: const TextStyle(fontWeight: FontWeight.w700)),
                    ]),
                  )
                : OutlinedButton.icon(
                    key: const ValueKey('todo'),
                    onPressed: _saving ? null : _complete,
                    icon: const Icon(Icons.done_rounded),
                    label: Text(s['mark_lesson_done']),
                  ),
          ),
          if (data.checkQuestionsCount > 0) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.quiz_rounded),
              label: Text('${s['mini_check']} · ${s.f('mini_check_desc', {'n': data.checkQuestionsCount})}'),
              onPressed: () async {
                if (!data.completed) await _complete();
                if (context.mounted) {
                  context.push('/test/lesson_check?ref=${data.id}&title=${Uri.encodeComponent(data.title)}');
                }
              },
            ),
          ],
        ]),
      ),
    );
  }
}
