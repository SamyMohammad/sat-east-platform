import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:sat_east_client/core/math_render/math_markup.dart';
import 'package:sat_east_client/core/text/text_direction.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/core/theme/booklet_type.dart';

/// Renders content text with TeX math and mixed Arabic/English (rule 8).
/// The only widget that knows the math engine.
class MathText extends StatelessWidget {
  const MathText(this.source, {super.key, this.style});

  final String source;
  final TextStyle? style;

  static final _glue = RegExp('^[.,;:!?)\\]\u00BB\u201D\u060C\u061B\u061F]+');

  @override
  Widget build(BuildContext context) {
    final segments = parseMathMarkup(source);
    final direction = detectTextDirection(
      segments.whereType<TextRun>().map((r) => r.text).join(),
    );
    var base = DefaultTextStyle.of(context).style.merge(style);
    if (direction == TextDirection.rtl) {
      base = base.merge(
        BookletType.arabic.copyWith(
          fontSize: base.fontSize,
          fontWeight: base.fontWeight,
          color: base.color,
        ),
      );
    }

    final children = <Widget>[];
    var inline = <MathSegment>[];
    void flushInline() {
      if (inline.isEmpty) return;
      children.add(
        Text.rich(
          TextSpan(style: base, children: _spans(inline, base)),
          textDirection: direction,
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

    return Directionality(
      textDirection: direction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: BookletSpace.s2,
        children: children,
      ),
    );
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
              child: _InlineMath(tex: tex, style: style, trailing: trailing),
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
