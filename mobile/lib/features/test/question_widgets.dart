import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/ui.dart';
import '../../core/widgets/markdown_view.dart';
import '../../data/models.dart';

const _letters = ['A', 'B', 'C', 'D', 'E', 'F'];

/// Task image: a file of a downloaded pack ("file://...") or an image served by the API.
Widget taskImage(
  String url, {
  double? width,
  BoxFit? fit,
  ImageLoadingBuilder? loadingBuilder,
  ImageErrorWidgetBuilder? errorBuilder,
}) {
  if (url.startsWith('file://')) {
    return Image.file(File(url.substring('file://'.length)), width: width, fit: fit, errorBuilder: errorBuilder);
  }
  return Image.network(AppConfig.mediaUrl(url),
      width: width, fit: fit, loadingBuilder: loadingBuilder, errorBuilder: errorBuilder);
}

Offset _centerOf(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  return box == null ? Offset.zero : box.localToGlobal(box.size.center(Offset.zero));
}

/// Shared text (reading passage), the question text and its image (formulas, figures, tables
/// from the task bank). The image opens full-screen with zoom.
class QuestionContent extends ConsumerWidget {
  final String? passage;
  final String text;
  final String? imageUrl;
  final String? source;
  const QuestionContent({super.key, this.passage, required this.text, this.imageUrl, this.source});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (passage != null && passage!.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            padding: EdgeInsets.zero,
            child: ExpansionTile(
              initiallyExpanded: true,
              shape: const Border(),
              collapsedShape: const Border(),
              leading: const IconBadge(Icons.article_rounded, colors: AppGradients.sky, size: 36, glow: false),
              title: Text(s['passage'], style: const TextStyle(fontWeight: FontWeight.w800)),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [MarkdownView(passage!)],
            ),
          ),
        ),
      if (imageUrl != null)
        Pressable(
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => Dialog.fullscreen(
              backgroundColor: Colors.white,
              child: Stack(children: [
                InteractiveViewer(
                  maxScale: 5,
                  child: Center(child: taskImage(imageUrl!)),
                ),
                const Positioned(top: 8, right: 8, child: CloseButton(color: Colors.black)),
              ]),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white, // the scans are black on white also in the dark theme
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: scheme.outlineVariant),
              boxShadow: softShadow(context),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(children: [
              taskImage(
                imageUrl!,
                width: double.infinity,
                fit: BoxFit.fitWidth,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
                errorBuilder: (_, __, ___) => SizedBox(
                  height: 80,
                  child: Center(child: Text(s['image_offline'], textAlign: TextAlign.center)),
                ),
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 18),
                ),
              ),
            ]),
          ),
        )
      else if (text.isNotEmpty)
        MarkdownView(text),
      if (source != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(source!, style: TextStyle(color: mutedOf(context), fontSize: 12)),
        ),
    ]);
  }
}

/// One option of a single-choice task (A–D). [text] is empty when the options are in the image.
class OptionTile extends ConsumerWidget {
  final int index;
  final String text;
  final AnswerFeedback? answer;
  final bool disabled;
  final void Function(Offset globalPosition) onTap;
  const OptionTile({
    super.key,
    required this.index,
    required this.text,
    required this.answer,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = BranchPalette.of(ref.watch(branchProvider));
    final selected = answer?.selectedIndex == index;
    final isCorrectOption = answer?.correctIndex == index;
    Color border = Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6);
    Color? fill;
    List<Color>? badge;
    IconData? icon;
    if (answer != null) {
      if (isCorrectOption) {
        border = AppColors.correct;
        fill = AppColors.correct.withValues(alpha: 0.1);
        badge = AppGradients.mint;
        icon = Icons.check_rounded;
      } else if (selected && answer!.isCorrect == false) {
        border = AppColors.wrong;
        fill = AppColors.wrong.withValues(alpha: 0.1);
        badge = AppGradients.rose;
        icon = Icons.close_rounded;
      } else if (selected) {
        border = palette.primary;
        fill = palette.primary.withValues(alpha: 0.08);
        badge = palette.gradient;
        icon = answer!.pending ? Icons.schedule_rounded : null;
      }
    }
    final highlighted = badge != null;
    return Builder(
      builder: (tileContext) => Pressable(
        onTap: disabled ? null : () => onTap(_centerOf(tileContext)),
        pressedScale: 0.97,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: fill ?? surfaceOf(context),
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: border, width: highlighted ? 2 : 1.2),
            boxShadow: highlighted ? null : softShadow(context, strength: 0.6),
          ),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: badge != null ? AppGradients.of(badge) : null,
                color: badge == null ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06) : null,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, a) =>
                    ScaleTransition(scale: CurvedAnimation(parent: a, curve: Curves.elasticOut), child: child),
                child: icon != null
                    ? Icon(icon, key: ValueKey(icon), color: Colors.white, size: 20)
                    : Text(_letters[index],
                        key: ValueKey('l$index$highlighted'),
                        style: TextStyle(fontWeight: FontWeight.w900, color: highlighted ? Colors.white : null)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
          ]),
        ),
      ),
    );
  }
}

/// Matching: for every item A–D choose one of 1–5 (one option is extra). 1 point per correct pair.
class MatchingInput extends ConsumerStatefulWidget {
  final Question question;
  final AnswerFeedback? answer;
  final bool disabled;
  final void Function(List<int> pairs, Offset globalPosition) onSubmit;
  const MatchingInput({
    super.key,
    required this.question,
    required this.answer,
    required this.disabled,
    required this.onSubmit,
  });

  @override
  ConsumerState<MatchingInput> createState() => _MatchingInputState();
}

class _MatchingInputState extends ConsumerState<MatchingInput> {
  late final List<int?> _pairs =
      widget.answer?.matching?.map<int?>((e) => e).toList() ?? List<int?>.filled(_left.length, null);

  List<String> get _left => widget.question.matchingLeft ?? const ['A', 'B', 'C', 'D'];

  bool get _textual => !widget.question.optionsInImage;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final q = widget.question;
    final correct = widget.answer?.correctMatching;
    final palette = BranchPalette.of(ref.watch(branchProvider));
    final complete = _pairs.every((p) => p != null);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_textual) ...[
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < q.options.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: palette.primary.withValues(alpha: 0.12)),
                    child: Text('${i + 1}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: palette.primary)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(q.options[i])),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 12),
      ],
      for (var row = 0; row < _left.length; row++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surfaceOf(context),
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(
                color: correct == null
                    ? Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6)
                    : (_pairs[row] == correct[row] ? AppColors.correct : AppColors.wrong),
                width: correct == null ? 1.2 : 2,
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_textual ? '${_letters[row]}) ${_left[row]}' : _letters[row],
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Row(children: [
                for (var opt = 0; opt < q.options.length; opt++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _NumberChip(
                      number: opt + 1,
                      selected: _pairs[row] == opt,
                      correct: correct != null && correct[row] == opt,
                      colors: palette.gradient,
                      onTap: widget.disabled
                          ? null
                          : () => setState(() => _pairs[row] = opt),
                    ),
                  ),
              ]),
            ]),
          ),
        ),
      if (widget.answer == null)
        Builder(
          builder: (buttonContext) => GradientButton(
            label: s['answer_button'],
            icon: Icons.check_rounded,
            onPressed: complete && !widget.disabled
                ? () => widget.onSubmit(_pairs.cast<int>(), _centerOf(buttonContext))
                : null,
          ),
        ),
    ]);
  }
}

class _NumberChip extends StatelessWidget {
  final int number;
  final bool selected;
  final bool correct;
  final List<Color> colors;
  final VoidCallback? onTap;
  const _NumberChip({
    required this.number,
    required this.selected,
    required this.correct,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = correct ? AppGradients.mint : (selected ? colors : null);
    return Pressable(
      onTap: onTap,
      pressedScale: 0.85,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: gradient != null ? AppGradients.of(gradient) : null,
          color: gradient == null ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06) : null,
          boxShadow: gradient != null
              ? [BoxShadow(color: gradient.last.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))]
              : null,
        ),
        child: correct && !selected
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
            : Text('$number',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: gradient != null ? Colors.white : null)),
      ),
    );
  }
}

/// Open task: a non-negative number as on the answer sheet — an integer or a decimal with a comma
/// (up to 9 digits and 4 decimals), no units.
class NumericInput extends ConsumerStatefulWidget {
  final AnswerFeedback? answer;
  final bool disabled;
  final void Function(String value, Offset globalPosition) onSubmit;
  const NumericInput({super.key, required this.answer, required this.disabled, required this.onSubmit});

  @override
  ConsumerState<NumericInput> createState() => _NumericInputState();
}

/// What may be typed so far: digits, then optionally one comma (a dot becomes a comma) and decimals.
final _partialNumber = RegExp(r'^\d{0,9}(,\d{0,4})?$');

class _NumericInputState extends ConsumerState<NumericInput> {
  late final _controller = TextEditingController(text: widget.answer?.answer.toString() ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _complete => RegExp(r'^\d{1,9}(,\d{1,4})?$').hasMatch(_controller.text);

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final answered = widget.answer != null;
    final ok = widget.answer?.isCorrect;
    final color = ok == null ? null : (ok ? AppColors.correct : AppColors.wrong);
    final border = color == null
        ? null
        : OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md), borderSide: BorderSide(color: color, width: 2));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: _controller,
        enabled: !answered && !widget.disabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          TextInputFormatter.withFunction((old, value) {
            final text = value.text.replaceAll('.', ',');
            return _partialNumber.hasMatch(text) ? value.copyWith(text: text) : old;
          }),
        ],
        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 4, color: color),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: '0',
          helperText: s['numeric_hint'],
          suffixIcon: ok == null
              ? null
              : Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded, color: color, size: 28),
          enabledBorder: border,
          disabledBorder: border,
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 14),
      if (!answered)
        Builder(
          builder: (buttonContext) => GradientButton(
            label: s['answer_button'],
            icon: Icons.check_rounded,
            onPressed: _complete && !widget.disabled
                ? () => widget.onSubmit(_controller.text, _centerOf(buttonContext))
                : null,
          ),
        ),
    ]);
  }
}
