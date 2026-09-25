import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/ui.dart';
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

  Future<void> _startCheck(Lesson data) async {
    if (!data.completed) await _complete();
    if (mounted) {
      context.push('/test/lesson_check?ref=${data.id}&title=${Uri.encodeComponent(data.title)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final lesson = ref.watch(lessonProvider(widget.lessonId));
    final colors = BranchPalette.of(ref.watch(branchProvider)).gradient;
    return Scaffold(
      body: AsyncBody<Lesson>(
        value: lesson,
        onRetry: () => ref.invalidate(lessonProvider(widget.lessonId)),
        loading: SafeArea(
          child: ListView(padding: const EdgeInsets.all(20), children: const [
            Skeleton(height: 160),
            SizedBox(height: 20),
            Skeleton(height: 16),
            SizedBox(height: 10),
            Skeleton(height: 16),
            SizedBox(height: 10),
            Skeleton(height: 16, width: 200),
            SizedBox(height: 24),
            Skeleton(height: 140),
          ]),
        ),
        builder: (data) => Stack(children: [
          ListView(controller: _scroll, padding: EdgeInsets.zero, children: [
            _LessonHeader(title: data.title, label: s['lesson'], completed: data.completed, colors: colors),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                FadeSlideIn(
                  delay: Stagger.of(2),
                  child: AppCard(padding: const EdgeInsets.fromLTRB(18, 18, 18, 10), child: MarkdownView(data.content)),
                ),
                for (final url in data.mediaUrls)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(Radii.lg),
                      child: Image.network(url, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                    ),
                  ),
                if (data.videoUrl != null) ...[
                  const SizedBox(height: 12),
                  AppCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      const IconBadge(Icons.play_arrow_rounded, colors: AppGradients.rose, size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s['video'], style: const TextStyle(fontWeight: FontWeight.w800)),
                          SelectableText(data.videoUrl!, style: TextStyle(color: mutedOf(context), fontSize: 12)),
                        ]),
                      ),
                    ]),
                  ),
                ],
                const SizedBox(height: 20),
                SmoothSwitcher(
                  child: data.completed
                      ? _DoneBanner(key: const ValueKey('done'), text: s['lesson_done'])
                      : SoftButton(
                          key: const ValueKey('todo'),
                          label: s['mark_lesson_done'],
                          icon: Icons.done_all_rounded,
                          color: AppColors.correct,
                          onPressed: _saving ? null : _complete,
                        ),
                ),
                if (data.checkQuestionsCount > 0) ...[
                  const SizedBox(height: 14),
                  _MiniCheckCard(
                    title: s['mini_check'],
                    subtitle: s.f('mini_check_desc', {'n': data.checkQuestionsCount}),
                    action: s['start_now'],
                    loading: _saving,
                    onTap: () => _startCheck(data),
                  ),
                ],
              ]),
            ),
          ]),
          // Reading progress stays visible while scrolling.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _readProgress > 0.02 ? 1 : 0,
                child: GradientBar(value: _readProgress, colors: colors, height: 4, track: Colors.transparent),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _LessonHeader extends StatelessWidget {
  final String title;
  final String label;
  final bool completed;
  final List<Color> colors;
  const _LessonHeader({required this.title, required this.label, required this.completed, required this.colors});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AuroraBackground(
      colors: colors,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(Radii.xl)),
      child: Stack(children: [
        Positioned(
          right: -24,
          bottom: -34,
          child: Icon(Icons.auto_stories_rounded, size: 170, color: Colors.white.withValues(alpha: 0.12)),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, top + 8, 20, 26),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GlassIconButton(icon: Icons.arrow_back_rounded, onPressed: () => Navigator.of(context).maybePop()),
            const SizedBox(height: 18),
            FadeSlideIn(
              child: Row(children: [
                Pill(label, icon: Icons.menu_book_rounded, onDark: true),
                if (completed) ...[
                  const SizedBox(width: 8),
                  const Pill('✓', icon: Icons.verified_rounded, onDark: true),
                ],
              ]),
            ),
            const SizedBox(height: 10),
            FadeSlideIn(
              delay: Stagger.of(1),
              child: Hero(
                tag: 'lesson-title-$title',
                child: Material(
                  type: MaterialType.transparency,
                  child: Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                          letterSpacing: -0.4)),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _DoneBanner extends StatelessWidget {
  final String text;
  const _DoneBanner({super.key, required this.text});

  @override
  Widget build(BuildContext context) => FadeSlideIn(
        scale: true,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.correct.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: AppColors.correct.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            const IconBadge(Icons.check_rounded, colors: AppGradients.mint, size: 36),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
          ]),
        ),
      );
}

/// Dark card inviting to the mini-check after the lesson.
class _MiniCheckCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String action;
  final bool loading;
  final VoidCallback onTap;
  const _MiniCheckCard({
    required this.title,
    required this.subtitle,
    required this.action,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: loading ? null : onTap,
        child: AuroraBackground(
          colors: const [Color(0xFF1E1B4B), Color(0xFF6366F1), Color(0xFFA855F7)],
          borderRadius: BorderRadius.circular(Radii.lg),
          child: Shine(
            borderRadius: BorderRadius.circular(Radii.lg),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                const Float(distance: 4, child: IconBadge(Icons.quiz_rounded, colors: AppGradients.gold, size: 52)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
                  ]),
                ),
                const SizedBox(width: 8),
                Pulse(
                  amplitude: 0.08,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: loading
                        ? const Padding(padding: EdgeInsets.all(13), child: CircularProgressIndicator(strokeWidth: 2.5))
                        : const Icon(Icons.play_arrow_rounded, color: Color(0xFF6366F1), size: 30),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
}
