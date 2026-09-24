import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import 'question_widgets.dart';

final resultProvider = FutureProvider.autoDispose
    .family<AttemptResult, int>((ref, id) => ref.watch(testingRepositoryProvider).result(id));

/// Test result: score, points, MMT estimate, achievements, review of mistakes, "Repeat mistakes".
class ResultScreen extends ConsumerStatefulWidget {
  final int attemptId;
  final AttemptResult? initial;
  const ResultScreen({super.key, required this.attemptId, this.initial});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  final _confetti = ConfettiController(duration: const Duration(seconds: 3));
  bool _onlyMistakes = false;
  bool _celebrated = false;

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  void _celebrate(AttemptResult r) {
    if (_celebrated) return;
    _celebrated = true;
    if ((r.accuracy >= 80 || r.newAchievements.isNotEmpty) && ref.read(richMotionProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _confetti.play());
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final AsyncValue<AttemptResult> value =
        widget.initial != null ? AsyncData(widget.initial!) : ref.watch(resultProvider(widget.attemptId));

    return Scaffold(
      appBar: AppBar(
        title: Text(s['result']),
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => context.pop()),
      ),
      body: Stack(children: [
        AsyncBody<AttemptResult>(
          value: value,
          onRetry: () => ref.invalidate(resultProvider(widget.attemptId)),
          builder: (r) {
            _celebrate(r);
            final review = _onlyMistakes ? r.review.where((i) => !i.isCorrect).toList() : r.review;
            return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
              _ScoreHero(result: r),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _Stat(label: s['earned'], value: r.score, icon: Icons.star_rounded, color: AppColors.gold)),
                const SizedBox(width: 12),
                Expanded(
                  child: _Stat(
                      label: s['bonus'], value: r.completionBonus, icon: Icons.card_giftcard_rounded, color: AppColors.streak),
                ),
              ]),
              if (r.mmtScore != null) ...[
                const SizedBox(height: 12),
                _MmtCard(score: r.mmtScore!, max: r.mmtMax),
              ],
              if (r.subjects.isNotEmpty) ...[
                SectionTitle(s['by_subtests']),
                for (final sb in r.subjects)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text('A${sb.position}  ', style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                        Expanded(child: Text(sb.title, style: const TextStyle(fontWeight: FontWeight.w700))),
                        Text('${sb.score.toStringAsFixed(1)} / ${sb.maxScore}',
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                      ]),
                      const SizedBox(height: 6),
                      AnimatedProgressBar(value: sb.maxPoints == 0 ? 0 : sb.points / sb.maxPoints),
                      const SizedBox(height: 4),
                      Text(s.f('points_of', {'p': sb.points, 'm': sb.maxPoints}),
                          style: Theme.of(context).textTheme.bodySmall),
                    ]),
                  ),
                Text(s['scale_note'], style: Theme.of(context).textTheme.bodySmall),
              ],
              if (r.newAchievements.isNotEmpty) ...[
                SectionTitle(s['new_achievement']),
                for (final a in r.newAchievements)
                  Padding(padding: const EdgeInsets.only(bottom: 8), child: _AchievementBanner(achievement: a)),
              ],
              const SizedBox(height: 16),
              if (r.review.any((i) => !i.isCorrect))
                FilledButton.icon(
                  icon: const Icon(Icons.replay_rounded),
                  label: Text(s['repeat_mistakes']),
                  onPressed: () => context.pushReplacement(
                      '/test/mistakes?title=${Uri.encodeComponent(s['repeat_mistakes'])}'),
                ),
              const SizedBox(height: 8),
              if (r.testType != 'mistakes')
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(s['try_again']),
                  onPressed: () => context.pushReplacement(
                      '/test/${r.testType}${r.referenceId != null ? '?ref=${r.referenceId}' : ''}'),
                ),
              const SizedBox(height: 8),
              TextButton(onPressed: () => context.pop(), child: Text(s['to_home'])),
              SectionTitle(
                s['review'],
                trailing: FilterChip(
                  label: Text(s['only_mistakes']),
                  selected: _onlyMistakes,
                  onSelected: (v) => setState(() => _onlyMistakes = v),
                ),
              ),
              for (var i = 0; i < review.length; i++)
                Padding(padding: const EdgeInsets.only(bottom: 12), child: _ReviewCard(item: review[i])),
            ]);
          },
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 40,
            emissionFrequency: 0.04,
            colors: const [AppColors.correct, AppColors.gold, Color(0xFF4F46E5), Color(0xFFF97316), Colors.pink],
          ),
        ),
      ]),
    );
  }
}

class _ScoreHero extends ConsumerWidget {
  final AttemptResult result;
  const _ScoreHero({required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final acc = result.accuracy;
    final color = acc >= 80 ? AppColors.correct : (acc >= 50 ? AppColors.gold : AppColors.wrong);
    final title = acc >= 80 ? s['result_great'] : (acc >= 50 ? s['result_good'] : s['result_try']);
    return Column(children: [
      const SizedBox(height: 8),
      SizedBox(
        width: 170,
        height: 170,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: acc / 100),
          duration: motion(ref, 1200, context: context),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => Stack(fit: StackFit.expand, children: [
            CircularProgressIndicator(
              value: v,
              strokeWidth: 14,
              strokeCap: StrokeCap.round,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              color: color,
            ),
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${(v * 100).round()}%', style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900)),
                Text(s['accuracy'], style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 4),
      Text(s.f('correct_of', {'c': result.correctCount, 't': result.totalCount}),
          style: Theme.of(context).textTheme.titleMedium),
    ]);
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _Stat({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => TapCard(
        child: Row(children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CountUp(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900), suffix: ''),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ]),
      );
}

class _MmtCard extends ConsumerWidget {
  final int score;
  final int max;
  const _MmtCard({required this.score, required this.max});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final palette = BranchPalette.abiturient;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: palette.gradient),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        const Icon(Icons.school_rounded, color: Colors.white, size: 40),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s['mmt_score'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            Text(s.f('mmt_scale', {'max': max}),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
          ]),
        ),
        CountUp(score, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

class _AchievementBanner extends StatelessWidget {
  final AchievementInfo achievement;
  const _AchievementBanner({required this.achievement});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.6, end: 1),
        duration: const Duration(milliseconds: 700),
        curve: Curves.elasticOut,
        builder: (context, v, child) => Transform.scale(scale: v, child: child),
        child: TapCard(
          color: AppColors.gold.withValues(alpha: 0.15),
          child: Row(children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.gold,
              child: Icon(achievementIcon(achievement.icon), color: Colors.white, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(achievement.title, style: const TextStyle(fontWeight: FontWeight.w800))),
            if (achievement.pointsReward > 0)
              Text('+${achievement.pointsReward}',
                  style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.gold)),
          ]),
        ),
      );
}

class _ReviewCard extends ConsumerWidget {
  final ReviewItem item;
  const _ReviewCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final partial = !item.isCorrect && item.points > 0;
    final color = item.isCorrect ? AppColors.correct : (partial ? AppColors.gold : AppColors.wrong);
    const letters = ['A', 'B', 'C', 'D', 'E', 'F'];

    String optionLabel(int i) {
      final text = i < item.options.length ? item.options[i] : '';
      return text.length > 1 ? '${letters[i]}) $text' : letters[i];
    }

    String yours;
    String right;
    switch (item.type) {
      case QuestionType.single:
        yours = item.answer is int ? optionLabel(item.answer as int) : s['no_answer'];
        right = item.correctIndex != null ? optionLabel(item.correctIndex!) : '—';
      case QuestionType.matching:
        String pairs(Object? v) => v is List
            ? [for (var i = 0; i < v.length; i++) '${letters[i]}–${(v[i] as int) + 1}'].join('  ')
            : s['no_answer'];
        yours = pairs(item.answer);
        right = pairs(item.correctAnswer);
      case QuestionType.numeric:
        yours = item.answer?.toString() ?? s['no_answer'];
        right = item.correctAnswer?.toString() ?? '—';
    }

    return TapCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(item.isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text('${item.points}/${item.maxPoints} ${s['pts_short']}',
                style: TextStyle(fontWeight: FontWeight.w800, color: color)),
          ),
        ]),
        const SizedBox(height: 8),
        QuestionContent(passage: item.passage, text: item.text, imageUrl: item.imageUrl, source: item.source),
        const SizedBox(height: 6),
        if (!item.isCorrect) Text('${s['your_answer']}: $yours', style: TextStyle(color: color)),
        Text('✓ $right', style: const TextStyle(color: AppColors.correct, fontWeight: FontWeight.w700)),
        if (item.explanation != null && item.explanation!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(item.explanation!, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ]),
    );
  }
}
