import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/markdown_view.dart';
import '../../data/models.dart';

const _letters = ['A', 'B', 'C', 'D', 'E', 'F'];

Offset _centerOf(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  return box == null ? Offset.zero : box.localToGlobal(box.size.center(Offset.zero));
}

/// Shared text (reading passage), the question text and its image (formulas, figures, tables
/// from the official collection). The image opens full-screen with zoom.
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
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            initiallyExpanded: true,
            shape: const Border(),
            leading: const Icon(Icons.article_outlined),
            title: Text(s['passage'], style: const TextStyle(fontWeight: FontWeight.w700)),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [MarkdownView(passage!)],
          ),
        ),
      if (imageUrl != null)
        GestureDetector(
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => Dialog.fullscreen(
              backgroundColor: Colors.white,
              child: Stack(children: [
                InteractiveViewer(
                  maxScale: 5,
                  child: Center(child: Image.network(AppConfig.mediaUrl(imageUrl!))),
                ),
                const Positioned(top: 8, right: 8, child: CloseButton(color: Colors.black)),
              ]),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white, // the scans are black on white also in the dark theme
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(children: [
              Image.network(
                AppConfig.mediaUrl(imageUrl!),
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
              const Positioned(right: 6, bottom: 6, child: Icon(Icons.zoom_in_rounded, color: Colors.black45)),
            ]),
          ),
        )
      else if (text.isNotEmpty)
        MarkdownView(text),
      if (source != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(source!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.outline)),
        ),
    ]);
  }
}

/// One option of a single-choice task (A–D). [text] is empty when the options are in the image.
class OptionTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = answer?.selectedIndex == index;
    final isCorrectOption = answer?.correctIndex == index;
    Color border = scheme.outlineVariant;
    Color? fill;
    IconData? icon;
    if (answer != null) {
      if (isCorrectOption) {
        border = AppColors.correct;
        fill = AppColors.correct.withValues(alpha: 0.12);
        icon = Icons.check_circle_rounded;
      } else if (selected && answer!.isCorrect == false) {
        border = AppColors.wrong;
        fill = AppColors.wrong.withValues(alpha: 0.12);
        icon = Icons.cancel_rounded;
      } else if (selected) {
        border = scheme.primary;
        fill = scheme.primaryContainer.withValues(alpha: 0.6);
        icon = answer!.pending ? Icons.schedule_rounded : Icons.radio_button_checked_rounded;
      }
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: fill ?? Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: answer != null && (selected || isCorrectOption) ? 2 : 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTapUp: disabled ? null : (d) => onTap(d.globalPosition),
          onTap: disabled ? null : () {},
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: scheme.surfaceContainerHighest, shape: BoxShape.circle),
                child: Text(_letters[index], style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
              if (icon != null)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.elasticOut,
                  builder: (context, v, child) => Transform.scale(scale: v, child: child),
                  child: Icon(icon, color: border),
                ),
            ]),
          ),
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
    final scheme = Theme.of(context).colorScheme;
    final complete = _pairs.every((p) => p != null);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_textual) ...[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var i = 0; i < q.options.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text('${i + 1}) ${q.options[i]}'),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
      ],
      for (var row = 0; row < _left.length; row++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: correct == null
                    ? scheme.outlineVariant
                    : (_pairs[row] == correct[row] ? AppColors.correct : AppColors.wrong),
                width: correct == null ? 1 : 2,
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_textual ? '${_letters[row]}) ${_left[row]}' : _letters[row],
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (var opt = 0; opt < q.options.length; opt++)
                  ChoiceChip(
                    label: Text('${opt + 1}'),
                    selected: _pairs[row] == opt,
                    selectedColor: correct != null && correct[row] == opt ? AppColors.correct.withValues(alpha: 0.3) : null,
                    avatar: correct != null && correct[row] == opt
                        ? const Icon(Icons.check_rounded, size: 16, color: AppColors.correct)
                        : null,
                    onSelected: widget.disabled
                        ? null
                        : (_) {
                            HapticFeedback.selectionClick();
                            setState(() => _pairs[row] = opt);
                          },
                  ),
              ]),
            ]),
          ),
        ),
      if (widget.answer == null)
        Builder(
          builder: (buttonContext) => FilledButton.icon(
            onPressed: complete && !widget.disabled
                ? () => widget.onSubmit(_pairs.cast<int>(), _centerOf(buttonContext))
                : null,
            icon: const Icon(Icons.check_rounded),
            label: Text(s['answer_button']),
          ),
        ),
    ]);
  }
}

/// Open task: the answer is a natural number typed digit by digit (no units), like on the answer sheet.
class NumericInput extends ConsumerStatefulWidget {
  final AnswerFeedback? answer;
  final bool disabled;
  final void Function(String value, Offset globalPosition) onSubmit;
  const NumericInput({super.key, required this.answer, required this.disabled, required this.onSubmit});

  @override
  ConsumerState<NumericInput> createState() => _NumericInputState();
}

class _NumericInputState extends ConsumerState<NumericInput> {
  late final _controller = TextEditingController(text: widget.answer?.answer.toString() ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final answered = widget.answer != null;
    final ok = widget.answer?.isCorrect;
    final color = ok == null ? null : (ok ? AppColors.correct : AppColors.wrong);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: _controller,
        enabled: !answered && !widget.disabled,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 6),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: '0',
          helperText: s['numeric_hint'],
          enabledBorder: color == null
              ? null
              : OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: color, width: 2)),
          disabledBorder: color == null
              ? null
              : OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: color, width: 2)),
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 12),
      if (!answered)
        Builder(
          builder: (buttonContext) => FilledButton.icon(
            onPressed: _controller.text.isNotEmpty && !widget.disabled
                ? () => widget.onSubmit(_controller.text, _centerOf(buttonContext))
                : null,
            icon: const Icon(Icons.check_rounded),
            label: Text(s['answer_button']),
          ),
        ),
    ]);
  }
}
