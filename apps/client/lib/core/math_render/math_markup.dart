import 'package:equatable/equatable.dart';

/// A piece of content text: a plain/bold run or TeX math.
sealed class MathSegment extends Equatable {
  const MathSegment();
}

final class TextRun extends MathSegment {
  const TextRun(this.text, {this.bold = false});

  final String text;
  final bool bold;

  @override
  List<Object?> get props => [text, bold];
}

/// `\( ... \)` — sits inside the line.
final class InlineMath extends MathSegment {
  const InlineMath(this.tex);

  final String tex;

  @override
  List<Object?> get props => [tex];
}

/// `\[ ... \]` — own line; `||` splits it into chunks that may wrap.
final class BlockMath extends MathSegment {
  const BlockMath(this.chunks);

  final List<String> chunks;

  @override
  List<Object?> get props => [chunks];
}

/// Parses content markup: `\(..\)`, `\[..\]` (with `||`), `**bold**`.
/// Unclosed delimiters are kept as literal text; never throws.
List<MathSegment> parseMathMarkup(String source) {
  final out = <MathSegment>[];
  final buffer = StringBuffer();
  var bold = false;
  var i = 0;

  void flush() {
    if (buffer.isEmpty) return;
    out.add(TextRun(buffer.toString(), bold: bold));
    buffer.clear();
  }

  while (i < source.length) {
    if (source.startsWith(r'\(', i)) {
      final end = source.indexOf(r'\)', i + 2);
      if (end != -1) {
        flush();
        final tex = source.substring(i + 2, end).trim();
        if (tex.isNotEmpty) out.add(InlineMath(tex));
        i = end + 2;
        continue;
      }
    } else if (source.startsWith(r'\[', i)) {
      final end = source.indexOf(r'\]', i + 2);
      if (end != -1) {
        flush();
        final chunks = source
            .substring(i + 2, end)
            .split('||')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .toList();
        if (chunks.isNotEmpty) out.add(BlockMath(chunks));
        i = end + 2;
        continue;
      }
    } else if (source.startsWith('**', i) &&
        (bold || _hasClosingBold(source, i + 2))) {
      flush();
      bold = !bold;
      i += 2;
      continue;
    }
    buffer.write(source[i]);
    i++;
  }
  flush();
  return out;
}

/// An opening `**` counts only if a closing `**` follows that is not
/// immediately preceded by a space (so `2 ** 3` stays literal).
bool _hasClosingBold(String source, int from) {
  if (from < source.length && source[from] == ' ') return false;
  return source.indexOf('**', from) != -1;
}
