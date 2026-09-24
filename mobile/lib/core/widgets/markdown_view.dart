import 'package:flutter/material.dart';

/// Minimal Markdown renderer for lesson content: headings, paragraphs, **bold**, *italic*,
/// bullet/numbered lists, > quotes, | tables | and ![images](url). No extra dependency,
/// which keeps the app light on budget devices.
class MarkdownView extends StatelessWidget {
  final String data;
  const MarkdownView(this.data, {super.key});

  @override
  Widget build(BuildContext context) {
    final blocks = <Widget>[];
    final lines = data.replaceAll('\r\n', '\n').split('\n');
    var i = 0;
    while (i < lines.length) {
      final line = lines[i].trimRight();
      if (line.trim().isEmpty) {
        i++;
        continue;
      }
      if (line.startsWith('|')) {
        final rows = <String>[];
        while (i < lines.length && lines[i].trim().startsWith('|')) {
          rows.add(lines[i].trim());
          i++;
        }
        blocks.add(_table(context, rows));
        continue;
      }
      final image = RegExp(r'^!\[(.*?)\]\((.+?)\)$').firstMatch(line.trim());
      if (image != null) {
        blocks.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(image.group(2)!, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          ),
        ));
        i++;
        continue;
      }
      final heading = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(line);
      if (heading != null) {
        final level = heading.group(1)!.length;
        final theme = Theme.of(context).textTheme;
        final style = switch (level) {
          1 => theme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          2 => theme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          _ => theme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        };
        blocks.add(Padding(
          padding: EdgeInsets.only(top: level == 1 ? 4 : 16, bottom: 8),
          child: Text.rich(_inline(heading.group(2)!, style)),
        ));
        i++;
        continue;
      }
      if (line.startsWith('>')) {
        final quote = <String>[];
        while (i < lines.length && lines[i].trimLeft().startsWith('>')) {
          quote.add(lines[i].trimLeft().substring(1).trim());
          i++;
        }
        final scheme = Theme.of(context).colorScheme;
        blocks.add(Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: scheme.primary, width: 4)),
          ),
          child: Text.rich(_inline(quote.join(' '), _body(context))),
        ));
        continue;
      }
      final bullet = RegExp(r'^\s*([-*]|\d+\.)\s+(.*)$').firstMatch(line);
      if (bullet != null) {
        final marker = bullet.group(1)!;
        blocks.add(Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 26,
              child: Text(marker == '-' || marker == '*' ? '•' : marker, style: _body(context)),
            ),
            Expanded(child: Text.rich(_inline(bullet.group(2)!, _body(context)))),
          ]),
        ));
        i++;
        continue;
      }
      final paragraph = <String>[];
      while (i < lines.length &&
          lines[i].trim().isNotEmpty &&
          !RegExp(r'^(#|>|\||\s*[-*]\s|\s*\d+\.\s|!\[)').hasMatch(lines[i])) {
        paragraph.add(lines[i].trim());
        i++;
      }
      blocks.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text.rich(_inline(paragraph.join(' '), _body(context))),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: blocks);
  }

  TextStyle? _body(BuildContext context) => Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5);

  Widget _table(BuildContext context, List<String> rows) {
    List<String> cells(String row) =>
        row.substring(1, row.endsWith('|') ? row.length - 1 : row.length).split('|').map((c) => c.trim()).toList();
    final data = rows.where((r) => !RegExp(r'^\|[\s\-:|]+\|?$').hasMatch(r)).map(cells).toList();
    if (data.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder.all(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(8)),
          children: [
            for (var r = 0; r < data.length; r++)
              TableRow(
                decoration: r == 0 ? BoxDecoration(color: scheme.primaryContainer.withValues(alpha: 0.6)) : null,
                children: [
                  for (final c in data[r])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Text.rich(_inline(c,
                          r == 0 ? _body(context)?.copyWith(fontWeight: FontWeight.w700) : _body(context))),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// **bold** and *italic* spans.
  TextSpan _inline(String text, TextStyle? style) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'(\*\*(.+?)\*\*|\*(.+?)\*)');
    var last = 0;
    for (final m in pattern.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      if (m.group(2) != null) {
        spans.add(TextSpan(text: m.group(2), style: const TextStyle(fontWeight: FontWeight.w800)));
      } else {
        spans.add(TextSpan(text: m.group(3), style: const TextStyle(fontStyle: FontStyle.italic)));
      }
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return TextSpan(style: style, children: spans);
  }
}
