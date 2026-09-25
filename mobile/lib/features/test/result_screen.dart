import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/ui.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../offline/offline_testing.dart';
import 'question_widgets.dart';

final resultProvider = FutureProvider.autoDispose.family<AttemptResult, int>((ref, id) async {
  if (id < 0) {
    // Negative ids are attempts taken offline from downloaded packs
    final local = await ref.watch(offlineTestingProvider).result(id);
    if (local == null) throw const ApiException('Attempt not found', statusCode: 404);
    return AttemptResult.fromJson(local);
  }
  return ref.watch(testingRepositoryProvider).result(id);
});

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
      body: Stack(children: [
        AsyncBody<AttemptResult>(
          value: value,
          onRetry: () => ref.invalidate(resultProvider(widget.attemptId)),
          builder: (r) {
            _celebrate(r);
            final review = _onlyMistakes ? r.review.where((i) => !i.isCorrect).toList() : r.review;
            var n = 0;
            Widget item(Widget child) => FadeSlideIn(delay: Stagger.of(n++, stepMs: 80, startMs: 300), child: child);
            return CustomScrollView(slivers: [
              SliverToBoxAdapter(
                child: Stack(children: [
                  Column(children: [_ScoreHero(result: r), const SizedBox(height: 50)]),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 0,
                    child: item(Row(children: [
                      Expanded(
                        child: _Stat(
                            label: s['earned'], value: r.score, icon: Icons.star_rounded, colors: AppGradients.gold),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Stat(
                          label: s['bonus'],
                          value: r.completionBonus,
                          icon: Icons.card_giftcard_rounded,
                          colors: AppGradients.fire,
                        ),
                      ),
                    ])),
                  ),
                ]),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                sliver: SliverList.list(children: [
                  if (r.pendingSync)
                    item(Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: const OfflineBanner(messageKey: 'result_pending_sync'),
                      ),
                    )),
                  if (r.mmtScore != null) item(_MmtCard(score: r.mmtScore!, max: r.mmtMax)),
                  if (r.subjects.isNotEmpty) ...[
                    SectionHeader(s['by_subtests']),
                    item(_Subtests(subjects: r.subjects)),
                    const SizedBox(height: 10),
                    Text(s['scale_note'], style: TextStyle(color: mutedOf(context), fontSize: 12)),
                  ],
                  if (r.newAchievements.isNotEmpty) ...[
                    SectionHeader(s['new_achievement']),
                    for (final (i, a) in r.newAchievements.indexed)
                      FadeSlideIn(
                        delay: Duration(milliseconds: 600 + 150 * i),
                        scale: true,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _AchievementBanner(achievement: a),
                        ),
                      ),
                  ],
                  const SizedBox(height: 20),
                  if (r.review.any((i) => !i.isCorrect)) ...[
                    item(GradientButton(
                      label: s['repeat_mistakes'],
                      icon: Icons.replay_rounded,
                      onPressed: () => context.pushReplacement(
                          '/test/mistakes?title=${Uri.encodeComponent(s['repeat_mistakes'])}'),
                    )),
                    const SizedBox(height: 10),
                  ],
                  if (r.testType != 'mistakes') ...[
                    item(SoftButton(
                      label: s['try_again'],
                      icon: Icons.refresh_rounded,
                      onPressed: () => context.pushReplacement(
                          '/test/${r.testType}${r.referenceId != null ? '?ref=${r.referenceId}' : ''}'),
                    )),
                    const SizedBox(height: 4),
                  ],
                  TextButton(onPressed: () => context.pop(), child: Text(s['to_home'])),
                  SectionHeader(
                    s['review'],
                    trailing: _MistakesToggle(
                      selected: _onlyMistakes,
                      label: s['only_mistakes'],
                      onTap: () => setState(() => _onlyMistakes = !_onlyMistakes),
                    ),
                  ),
                  SmoothSwitcher(
                    child: Column(
                      key: ValueKey(_onlyMistakes),
                      children: [
                        for (final item in review)
                          Padding(padding: const EdgeInsets.only(bottom: 12), child: _ReviewCard(item: item)),
                      ],
                    ),
                  ),
                ]),
              ),
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
            colors: const [AppColors.correct, AppColors.gold, Color(0xFF6366F1), Color(0xFFF97316), Colors.pink],
          ),
        ),
      ]),
    );
  }
}

/// Coloured header: accuracy ring counting up, verdict, correct answers.
class _ScoreHero extends ConsumerWidget {
  final AttemptResult result;
  const _ScoreHero({required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final acc = result.accuracy;
    final colors = acc >= 80
        ? const [Color(0xFF10B981), Color(0xFF0EA5E9)]
        : (acc >= 50 ? const [Color(0xFFF59E0B), Color(0xFFF97316)] : const [Color(0xFFF43F5E), Color(0xFFA855F7)]);
    final title = acc >= 80 ? s['result_great'] : (acc >= 50 ? s['result_good'] : s['result_try']);
    final icon =
        acc >= 80 ? Icons.emoji_events_rounded : (acc >= 50 ? Icons.thumb_up_alt_rounded : Icons.trending_up_rounded);
    final white85 = Colors.white.withValues(alpha: 0.85);
    return AuroraBackground(
      colors: colors,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 64),
          child: Column(children: [
            Row(children: [
              GlassIconButton(icon: Icons.close_rounded, onPressed: () => context.pop()),
              Expanded(
                child: Text(s['result'],
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 44),
            ]),
            const SizedBox(height: 12),
            FadeSlideIn(
              scale: true,
              offset: Offset.zero,
              child: ProgressRing(
                value: acc / 100,
                size: 190,
                stroke: 16,
                duration: const Duration(milliseconds: 1400),
                colors: const [Color(0xFFFFF3B0), Colors.white],
                track: Colors.white.withValues(alpha: 0.22),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Float(distance: 3, child: Icon(icon, color: Colors.white, size: 30)),
                  CountUp(acc,
                      suffix: '%',
                      style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900, height: 1.1)),
                  Text(s['accuracy'], style: TextStyle(color: white85, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(
              delay: const Duration(milliseconds: 250),
              child: Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            ),
            const SizedBox(height: 4),
            FadeSlideIn(
              delay: const Duration(milliseconds: 350),
              child: Text(s.f('correct_of', {'c': result.correctCount, 't': result.totalCount}),
                  style: TextStyle(color: white85, fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final List<Color> colors;
  const _Stat({required this.label, required this.value, required this.icon, required this.colors});

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          IconBadge(icon, colors: colors, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CountUp(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: mutedOf(context), fontSize: 12.5, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      );
}

class _Subtests extends ConsumerWidget {
  final List<SubjectBreakdown> subjects;
  const _Subtests({required this.subjects});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final primary = Theme.of(context).colorScheme.primary;
    return AppCard(
      child: Column(children: [
        for (final (i, sb) in subjects.indexed) ...[
          if (i > 0) const SizedBox(height: 16),
          Row(children: [
            Pill('A${sb.position}', color: primary),
            const SizedBox(width: 10),
            Expanded(child: Text(sb.title, style: const TextStyle(fontWeight: FontWeight.w800))),
            Text('${sb.score.toStringAsFixed(1)} / ${sb.maxScore}', style: const TextStyle(fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 8),
          GradientBar(
            value: sb.maxPoints == 0 ? 0 : sb.points / sb.maxPoints,
            colors: BranchPalette.abiturient.gradient,
            height: 8,
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(s.f('points_of', {'p': sb.points, 'm': sb.maxPoints}),
                style: TextStyle(color: mutedOf(context), fontSize: 12)),
          ),
        ],
      ]),
    );
  }
}

class _MmtCard extends ConsumerWidget {
  final int score;
  final int max;
  const _MmtCard({required this.score, required this.max});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    const colors = [Color(0xFF0F172A), Color(0xFF4338CA)];
    final radius = BorderRadius.circular(Radii.lg);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [BoxShadow(color: colors.last.withValues(alpha: 0.4), blurRadius: 22, offset: const Offset(0, 10))],
      ),
      child: AuroraBackground(
        colors: colors,
        borderRadius: radius,
        child: Shine(
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              const IconBadge(Icons.school_rounded, colors: AppGradients.violet, size: 52),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s['mmt_score'],
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                  Text(s.f('mmt_scale', {'max': max}),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5)),
                  const SizedBox(height: 8),
                  GradientBar(
                    value: max == 0 ? 0 : score / max,
                    colors: const [Color(0xFFA78BFA), Color(0xFFF0ABFC)],
                    track: Colors.white.withValues(alpha: 0.15),
                    height: 7,
                  ),
                ]),
              ),
              const SizedBox(width: 14),
              CountUp(score, style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _AchievementBanner extends StatelessWidget {
  final AchievementInfo achievement;
  const _AchievementBanner({required this.achievement});

  @override
  Widget build(BuildContext context) => AppCard(
        gradient: AppGradients.of([AppColors.gold.withValues(alpha: 0.18), AppColors.gold.withValues(alpha: 0.06)]),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
        child: Row(children: [
          Pulse(
            amplitude: 0.08,
            child: Shine(
              borderRadius: BorderRadius.circular(18),
              period: const Duration(milliseconds: 2400),
              child: IconBadge(achievementIcon(achievement.icon), colors: AppGradients.gold, size: 54),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(achievement.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          ),
          if (achievement.pointsReward > 0)
            Pill('+${achievement.pointsReward}', icon: Icons.star_rounded, color: AppColors.gold),
        ]),
      );
}

class _MistakesToggle extends StatelessWidget {
  final bool selected;
  final String label;
  final VoidCallback onTap;
  const _MistakesToggle({required this.selected, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            gradient: selected ? AppGradients.of(AppGradients.rose) : null,
            color: selected ? null : AppColors.wrong.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(selected ? Icons.check_rounded : Icons.filter_list_rounded,
                size: 16, color: selected ? Colors.white : AppColors.wrong),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 13, color: selected ? Colors.white : AppColors.wrong)),
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

    return AppCard(
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            width: 6,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(Radii.lg)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(item.isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${item.points}/${item.maxPoints} ${s['pts_short']}',
                        style: TextStyle(fontWeight: FontWeight.w800, color: color)),
                  ),
                ]),
                const SizedBox(height: 8),
                QuestionContent(passage: item.passage, text: item.text, imageUrl: item.imageUrl, source: item.source),
                const SizedBox(height: 8),
                if (!item.isCorrect)
                  Text('${s['your_answer']}: $yours', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                Text('✓ $right', style: const TextStyle(color: AppColors.correct, fontWeight: FontWeight.w800)),
                if (item.explanation != null && item.explanation!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.lightbulb_rounded, size: 18, color: AppColors.gold),
                      const SizedBox(width: 8),
                      Expanded(child: Text(item.explanation!, style: Theme.of(context).textTheme.bodyMedium)),
                    ]),
                  ),
                ],
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
