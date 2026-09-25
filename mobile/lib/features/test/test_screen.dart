import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/ui.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/markdown_view.dart';
import '../../data/models.dart';
import 'question_widgets.dart';
import 'test_controller.dart';

export 'test_controller.dart' show TestLaunch;

/// Question + timer + answer input (choice / matching / number), with answer animations.
class TestScreen extends ConsumerStatefulWidget {
  final TestLaunch launch;
  const TestScreen({super.key, required this.launch});

  @override
  ConsumerState<TestScreen> createState() => _TestScreenState();
}

class _FlyEntry {
  final int id;
  final int points;
  final bool bonus;
  final Offset from;
  _FlyEntry(this.id, this.points, this.bonus, this.from);
}

class _TestScreenState extends ConsumerState<TestScreen> {
  final _scoreKey = GlobalKey();
  final _stackKey = GlobalKey();
  final _flies = <_FlyEntry>[];
  Offset? _lastTap;
  int _flyId = 0;
  int _shakeTick = 0;
  Color? _flash;

  late final _provider = testControllerProvider(widget.launch);

  Offset _localOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || stack == null) return Offset.zero;
    return stack.globalToLocal(box.localToGlobal(Offset.zero));
  }

  void _rememberTap(Offset globalPosition) {
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    _lastTap = stack?.globalToLocal(globalPosition);
  }

  void _onEvent(TestState state) {
    final rich = ref.read(richMotionProvider);
    void fly() {
      if (rich && state.lastPoints > 0) {
        final from = _lastTap ?? Offset(MediaQuery.sizeOf(context).width / 2, MediaQuery.sizeOf(context).height / 2);
        setState(() => _flies.add(_FlyEntry(_flyId++, state.lastPoints, state.lastStreakBonus, from)));
      }
    }

    switch (state.event) {
      case TestEvent.correct:
        HapticFeedback.mediumImpact();
        setState(() => _flash = AppColors.correct);
        fly();
      case TestEvent.partial:
        HapticFeedback.lightImpact();
        setState(() => _flash = AppColors.gold);
        fly();
      case TestEvent.wrong:
        HapticFeedback.heavyImpact();
        setState(() {
          _flash = AppColors.wrong;
          _shakeTick++;
        });
      case TestEvent.queued:
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(ref.read(stringsProvider)['answer_queued']),
            behavior: SnackBarBehavior.floating,
          ));
      case TestEvent.saved:
        HapticFeedback.selectionClick();
      case TestEvent.none:
        break;
    }
    if (_flash != null) {
      Future.delayed(const Duration(milliseconds: 380), () {
        if (mounted) setState(() => _flash = null);
      });
    }
  }

  Future<bool> _confirmFinish(Strings s) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const IconBadge(Icons.flag_rounded, colors: AppGradients.violet, size: 56),
          content: Text(s['finish_confirm'], textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s['cancel'])),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(s['finish'])),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final state = ref.watch(_provider);
    final controller = ref.read(_provider.notifier);

    ref.listen<TestState>(_provider, (prev, next) {
      if (prev?.eventTick != next.eventTick) _onEvent(next);
      if (next.result != null && prev?.result == null) {
        context.pushReplacement('/result/${next.result!.attemptId}', extra: next.result);
      }
      if (next.finishError != null && prev?.finishError != next.finishError) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next.finishError == 'offline' ? s['need_network_finish'] : s['error_generic']),
          behavior: SnackBarBehavior.floating,
        ));
      }
    });

    if (state.error != null) {
      final e = state.error!;
      final nothing = e.toString() == 'No questions available';
      return Scaffold(
        appBar: AppBar(),
        body: nothing
            ? Center(
                child: EmptyState(
                    icon: Icons.celebration_rounded, text: s['nothing_to_repeat'], colors: AppGradients.mint))
            : ErrorView(error: e, onRetry: controller.load),
      );
    }
    if (state.loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.launch.title ?? '')),
        body: ListView(padding: const EdgeInsets.all(20), children: const [
          Skeleton(height: 10),
          SizedBox(height: 24),
          Skeleton(height: 120),
          SizedBox(height: 24),
          Skeleton(height: 60),
          SizedBox(height: 12),
          Skeleton(height: 60),
          SizedBox(height: 12),
          Skeleton(height: 60),
          SizedBox(height: 12),
          Skeleton(height: 60),
        ]),
      );
    }

    final q = state.current!;
    final answer = state.currentAnswer;
    final total = state.questions.length;
    final lastQuestion = state.allAnswered;
    final locked = answer != null || state.submitting;

    Widget input;
    switch (q.type) {
      case QuestionType.single:
        input = Column(children: [
          for (var i = 0; i < q.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OptionTile(
                index: i,
                text: q.optionsInImage ? '' : q.options[i],
                answer: answer,
                disabled: locked,
                onTap: (pos) {
                  _rememberTap(pos);
                  controller.answer(i);
                },
              ),
            ),
        ]);
      case QuestionType.matching:
        input = MatchingInput(
          key: ValueKey('m${q.id}'),
          question: q,
          answer: answer,
          disabled: locked,
          onSubmit: (pairs, pos) {
            _rememberTap(pos);
            controller.answer(pairs);
          },
        );
      case QuestionType.numeric:
        input = NumericInput(
          key: ValueKey('n${q.id}'),
          answer: answer,
          disabled: locked,
          onSubmit: (value, pos) {
            _rememberTap(pos);
            controller.answer(value);
          },
        );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => context.pop()),
        title: Text(widget.launch.title ?? s['test_type_${widget.launch.testType}'],
            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17)),
        actions: [
          if (state.remaining != null) _TimerChip(remaining: state.remaining!),
          if (state.showsFeedback) ...[
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
              child: state.streak >= 3
                  ? Padding(
                      key: const ValueKey('streak'),
                      padding: const EdgeInsets.only(right: 6),
                      child: Pulse(
                        amplitude: 0.12,
                        period: const Duration(milliseconds: 800),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: AppGradients.of(AppGradients.fire),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(children: [
                            const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 18),
                            Text('${state.streak}',
                                style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
                          ]),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            Container(
              key: _scoreKey,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: AppGradients.of(AppGradients.gold),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.35), blurRadius: 10)],
              ),
              child: Row(children: [
                const Icon(Icons.star_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 2),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                  child: Text('${state.score}',
                      key: ValueKey(state.score),
                      style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
                ),
              ]),
            ),
          ],
        ],
      ),
      body: Stack(key: _stackKey, children: [
        Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GradientBar(
              value: state.answers.length / total,
              colors: BranchPalette.of(ref.watch(branchProvider)).gradient,
              height: 10,
            ),
          ),
          _QuestionStrip(state: state, onTap: controller.goTo),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.f('question_n_of', {'n': state.index + 1, 'total': total}),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                    const SizedBox(height: 6),
                    _TypeBadge(question: q),
                  ]),
                ),
                _MarkButton(
                  marked: state.marked.contains(q.id),
                  label: state.marked.contains(q.id) ? s['marked'] : s['mark_question'],
                  onTap: controller.toggleMark,
                ),
              ]),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: motion(ref, 300, context: context),
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0.08, 0), end: Offset.zero).animate(a),
                    child: child,
                  ),
                ),
                child: Column(
                  key: ValueKey(q.id),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppCard(
                      child: QuestionContent(
                        passage: q.passage,
                        text: q.text,
                        imageUrl: q.imageUrl,
                        source: q.source,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Shake(trigger: _shakeTick, child: input),
                    if (answer != null && state.showsFeedback) FeedbackPanel(question: q, answer: answer),
                  ],
                ),
              ),
            ]),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(children: [
                if (!lastQuestion && answer != null && state.showsFeedback)
                  Expanded(
                    child: FadeSlideIn(
                      offset: const Offset(0, 16),
                      child: GradientButton(
                        label: s['next_question'],
                        icon: Icons.arrow_forward_rounded,
                        onPressed: controller.next,
                      ),
                    ),
                  ),
                if (lastQuestion || !state.showsFeedback) ...[
                  if (!lastQuestion && !state.showsFeedback) ...[
                    Expanded(
                      child: SoftButton(label: s['skip'], height: 56, onPressed: controller.next),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: GradientButton(
                      label: s['finish_test'],
                      icon: Icons.flag_rounded,
                      loading: state.finishing,
                      onPressed: () async {
                        if (!lastQuestion && !await _confirmFinish(s)) return;
                        controller.finish();
                      },
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ]),
        // Green/red flash on answer
        IgnorePointer(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            color: (_flash ?? Colors.transparent).withValues(alpha: _flash == null ? 0 : 0.14),
          ),
        ),
        for (final f in _flies)
          FlyingPoints(
            key: ValueKey(f.id),
            points: f.points,
            bonus: f.bonus,
            from: f.from - const Offset(20, 20),
            to: _localOf(_scoreKey),
            onDone: () => setState(() => _flies.removeWhere((e) => e.id == f.id)),
          ),
      ]),
    );
  }
}

class _TypeBadge extends ConsumerWidget {
  final Question question;
  const _TypeBadge({required this.question});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final label = switch (question.type) {
      QuestionType.single => s['type_single'],
      QuestionType.matching => s['type_matching'],
      QuestionType.numeric => s['type_numeric'],
    };
    final icon = switch (question.type) {
      QuestionType.single => Icons.radio_button_checked_rounded,
      QuestionType.matching => Icons.compare_arrows_rounded,
      QuestionType.numeric => Icons.pin_rounded,
    };
    return Pill('$label · ${question.maxPoints} ${s['pts_short']}', icon: icon);
  }
}

class _TimerChip extends StatelessWidget {
  final Duration remaining;
  const _TimerChip({required this.remaining});

  @override
  Widget build(BuildContext context) {
    final urgent = remaining.inSeconds < 60;
    final h = remaining.inHours;
    final m = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    final chip = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (urgent ? AppColors.wrong : Theme.of(context).colorScheme.primary).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: (urgent ? AppColors.wrong : Theme.of(context).colorScheme.primary).withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(Icons.timer_outlined, size: 18, color: urgent ? AppColors.wrong : null),
        const SizedBox(width: 4),
        Text(h > 0 ? '$h:$m:$sec' : '$m:$sec',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: urgent ? AppColors.wrong : null,
            )),
      ]),
    );
    return urgent ? Pulse(amplitude: 0.06, period: const Duration(milliseconds: 600), child: chip) : chip;
  }
}

/// Bookmark toggle: the icon pops when a question is marked for review.
class _MarkButton extends StatelessWidget {
  final bool marked;
  final String label;
  final VoidCallback onTap;
  const _MarkButton({required this.marked, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = marked ? AppColors.gold : mutedOf(context);
    return Tooltip(
      message: label,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: marked ? AppColors.gold.withValues(alpha: 0.16) : mutedOf(context).withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, a) =>
                ScaleTransition(scale: CurvedAnimation(parent: a, curve: Curves.elasticOut), child: child),
            child: Icon(marked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                key: ValueKey(marked), color: color, size: 22),
          ),
        ),
      ),
    );
  }
}

/// Numbers of all questions; tap to jump (useful in exam mode).
class _QuestionStrip extends StatelessWidget {
  final TestState state;
  final void Function(int) onTap;
  const _QuestionStrip({required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        itemCount: state.questions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final a = state.answers[state.questions[i].id];
          final List<Color>? gradient;
          if (a == null) {
            gradient = null;
          } else if (a.isCorrect == true) {
            gradient = AppGradients.mint;
          } else if (a.isCorrect == false) {
            gradient = (a.points ?? 0) > 0 ? AppGradients.gold : AppGradients.rose;
          } else {
            gradient = [scheme.primary, scheme.secondary];
          }
          final current = i == state.index;
          return GestureDetector(
            onTap: () => onTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              width: current ? 38 : 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: gradient != null ? AppGradients.of(gradient) : null,
                color: gradient == null ? scheme.onSurface.withValues(alpha: 0.07) : null,
                borderRadius: BorderRadius.circular(16),
                border: current ? Border.all(color: scheme.primary, width: 2.5) : null,
              ),
              child: Text('${i + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: a == null ? scheme.onSurface : Colors.white,
                  )),
            ),
          );
        },
      ),
    );
  }
}

/// Correct/incorrect + explanation, shown only AFTER the user answered.
class FeedbackPanel extends ConsumerWidget {
  final Question question;
  final AnswerFeedback answer;
  const FeedbackPanel({super.key, required this.question, required this.answer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    if (answer.pending || answer.isCorrect == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(answer.pending ? s['answer_queued'] : s['answer_saved'],
            style: Theme.of(context).textTheme.bodyMedium),
      );
    }
    final ok = answer.isCorrect!;
    final partial = !ok && (answer.points ?? 0) > 0;
    final color = ok ? AppColors.correct : (partial ? AppColors.gold : AppColors.wrong);
    final title = ok ? s['correct'] : (partial ? s['partially'] : s['wrong']);
    String? correctText;
    if (question.type == QuestionType.numeric && !ok) {
      correctText = '${s['correct_answer']}: ${answer.correctAnswer}';
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) =>
          Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 20 * (1 - v)), child: child)),
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            IconBadge(ok ? Icons.check_rounded : (partial ? Icons.more_horiz_rounded : Icons.close_rounded),
                colors: ok ? AppGradients.mint : (partial ? AppGradients.gold : AppGradients.rose), size: 36),
            const SizedBox(width: 10),
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18)),
            const Spacer(),
            if (answer.points != null)
              Text('${answer.points}/${question.maxPoints} ${s['pts_short']}',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800)),
            if (answer.pointsAwarded > 0) ...[
              const SizedBox(width: 8),
              Text('+${answer.pointsAwarded}', style: TextStyle(color: color, fontWeight: FontWeight.w900)),
            ],
          ]),
          if (correctText != null) ...[
            const SizedBox(height: 8),
            Text(correctText, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
          if (answer.explanation != null && answer.explanation!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.lightbulb_rounded, color: AppColors.gold, size: 18),
              const SizedBox(width: 6),
              Text(s['explanation'], style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 4),
            MarkdownView(answer.explanation!),
          ],
        ]),
      ),
    );
  }
}
