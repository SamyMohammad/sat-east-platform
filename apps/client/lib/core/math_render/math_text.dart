import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:sat_east_client/core/math_render/math_markup.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/core/theme/booklet_type.dart';

/// Renders English content text with TeX math.
/// The only widget that knows the math engine.
class MathText extends StatelessWidget {
  const MathText(this.source, {super.key, this.style});

  final String source;
  final TextStyle? style;

  static final _glue = RegExp('^[.,;:!?)\\]\u00BB\u201D]+');

  @override
  Widget build(BuildContext context) {
    final paragraphs = _paragraphs(parseMathMarkup(source));
    final baseStyle = DefaultTextStyle.of(context).style.merge(style);

    final children = [
      for (final segments in paragraphs) ..._paragraph(segments, baseStyle),
    ];

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: BookletSpace.s2,
        children: children,
      ),
    );
  }

  static final _blankLine = RegExp(r'\n\s*\n');

  /// Splits segments into paragraphs on blank lines.
  /// Only [TextRun]s are split, so a blank line inside a block
  /// equation `\[...\]` never breaks it.
  static List<List<MathSegment>> _paragraphs(List<MathSegment> segments) {
    final out = <List<MathSegment>>[[]];
    for (final s in segments) {
      if (s is! TextRun) {
        out.last.add(s);
        continue;
      }
      final parts = s.text.split(_blankLine);
      for (var i = 0; i < parts.length; i++) {
        if (i > 0) out.add([]);
        // Pieces created by a split that are empty add nothing.
        if (parts.length > 1 && parts[i].isEmpty) continue;
        out.last.add(TextRun(parts[i], bold: s.bold));
      }
    }
    if (out.length > 1) out.removeWhere((p) => p.isEmpty);
    return out.isEmpty ? [[]] : out;
  }

  List<Widget> _paragraph(
    List<MathSegment> segments,
    TextStyle baseStyle,
  ) {
    final base = baseStyle;
    final children = <Widget>[];
    var inline = <MathSegment>[];
    void flushInline() {
      if (inline.isEmpty) return;
      children.add(
        Text.rich(
          TextSpan(style: base, children: _spans(inline, base)),
          textDirection: TextDirection.ltr,
        ),
      );
      inline = [];
    }

    // Whitespace next to a block equation would show as a stray indent.
    var afterBlock = false;
    for (final s in segments) {
      if (s is BlockMath) {
        if (inline.lastOrNull case TextRun(:final text, :final bold)) {
          inline.last = TextRun(text.trimRight(), bold: bold);
        }
        flushInline();
        children.add(_BlockMathView(chunks: s.chunks, style: base));
        afterBlock = true;
      } else {
        if (afterBlock && s is TextRun) {
          final trimmed = s.text.trimLeft();
          if (trimmed.isNotEmpty) inline.add(TextRun(trimmed, bold: s.bold));
        } else {
          inline.add(s);
        }
        afterBlock = false;
      }
    }
    flushInline();
    return children;
  }

  List<InlineSpan> _spans(List<MathSegment> source, TextStyle style) {
    final segs = [...source];
    final spans = <InlineSpan>[];
    for (var i = 0; i < segs.length; i++) {
      switch (segs[i]) {
        case TextRun(:final text, :final bold):
          if (text.isEmpty) continue;
          spans.add(
            TextSpan(
              text: text,
              style: bold ? const TextStyle(fontWeight: FontWeight.w600) : null,
            ),
          );
        case InlineMath(:final tex):
          String? trailing;
          if (i + 1 < segs.length) {
            final next = segs[i + 1];
            if (next is TextRun) {
              final m = _glue.firstMatch(next.text);
              if (m != null) {
                trailing = m[0];
                segs[i + 1] = TextRun(
                  next.text.substring(m.end),
                  bold: next.bold,
                );
              }
            }
          }
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              // WidgetSpan scales its child; Math.tex must not scale it again.
              child: MediaQuery.withNoTextScaling(
                child: _InlineMath(tex: tex, style: style, trailing: trailing),
              ),
            ),
          );
        case BlockMath():
          break; // blocks are laid out by build()
      }
    }
    return spans;
  }
}

TextStyle _mathStyle(TextStyle style) => style.copyWith(
  fontSize: (style.fontSize ?? 16) * BookletType.mathScale,
);

Widget _tex(String tex, TextStyle style, MathStyle mathStyle) => Math.tex(
  tex,
  mathStyle: mathStyle,
  textStyle: _mathStyle(style),
  onErrorFallback: (_) => Text(tex, style: style),
);

class _InlineMath extends StatelessWidget {
  const _InlineMath({required this.tex, required this.style, this.trailing});

  final String tex;
  final TextStyle style;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final math = Directionality(
      textDirection: TextDirection.ltr,
      child: _tex(tex, style, MathStyle.text),
    );
    final punct = trailing;
    if (punct == null) return math;
    // Row follows the paragraph direction, so punctuation lands at its end.
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        math,
        Text(punct, style: style),
      ],
    );
  }
}

class _BlockMathView extends StatelessWidget {
  const _BlockMathView({required this.chunks, required this.style});

  final List<String> chunks;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final content = chunks.length == 1
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _tex(chunks.single, style, MathStyle.display),
          )
        : Wrap(
            spacing: (style.fontSize ?? 16) * 0.35,
            runSpacing: BookletSpace.s2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final c in chunks) _tex(c, style, MathStyle.display),
            ],
          );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: BookletSize.blockMathMinHeight,
        ),
        child: Align(alignment: Alignment.centerLeft, child: content),
      ),
    );
  }
}
