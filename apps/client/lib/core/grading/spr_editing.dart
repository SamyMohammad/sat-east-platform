/// SPR editing rules for the custom keypad and the text field (F-4).
/// Input only — grading stays server-side.
library;

import 'package:sat_east_client/core/grading/spr_answer.dart';

/// Hard cap on typed characters. Above the 6-char grading rule on purpose,
/// so the "too long" hint can still show.
const int sprInputMaxChars = sprMaxLengthNegative + 2;

/// A key on the SPR keypad.
enum SprKey {
  zero('0'),
  one('1'),
  two('2'),
  three('3'),
  four('4'),
  five('5'),
  six('6'),
  seven('7'),
  eight('8'),
  nine('9'),
  slash('/'),
  dot('.'),
  minus('-'),
  backspace(null);

  const SprKey(this.char);

  /// Character the key inserts (ASCII); null for actions.
  final String? char;

  static SprKey digit(int n) => values[n];
}

/// Why a keypad key was ignored.
enum SprKeyHint { secondSlash, secondDot, slashAndDot }

typedef SprEdit = ({String text, SprKeyHint? hint});

/// Applies one keypad [key] to [text].
SprEdit applySprKey(String text, SprKey key) {
  if (key == SprKey.backspace) {
    return (
      text: text.isEmpty ? text : text.substring(0, text.length - 1),
      hint: null,
    );
  }
  if (key == SprKey.minus) {
    return (
      text: text.startsWith('-') ? text.substring(1) : '-$text',
      hint: null,
    );
  }
  if (key == SprKey.slash) {
    if (text.contains('/')) return (text: text, hint: SprKeyHint.secondSlash);
    if (text.contains('.')) return (text: text, hint: SprKeyHint.slashAndDot);
  }
  if (key == SprKey.dot) {
    if (text.contains('.')) return (text: text, hint: SprKeyHint.secondDot);
    if (text.contains('/')) return (text: text, hint: SprKeyHint.slashAndDot);
  }
  if (text.length >= sprInputMaxChars) return (text: text, hint: null);
  return (text: '$text${key.char}', hint: null);
}

/// Maps keyboard digits from Arabic-Indic / Persian layouts, their decimal
/// separator and
/// U+2212 minus to ASCII. One UTF-16 unit in, one out (keeps selections valid).
String normalizeSprDigits(String input) {
  final out = StringBuffer();
  for (final unit in input.codeUnits) {
    if (unit >= 0x0660 && unit <= 0x0669) {
      out.writeCharCode(0x30 + unit - 0x0660);
    } else if (unit >= 0x06F0 && unit <= 0x06F9) {
      out.writeCharCode(0x30 + unit - 0x06F0);
    } else if (unit == 0x066B) {
      out.write('.');
    } else if (unit == 0x2212) {
      out.write('-');
    } else {
      out.writeCharCode(unit);
    }
  }
  return out.toString();
}

/// TeX for the Answer Preview, built from the typed text (not reduced, like
/// the official preview). Null until [input] parses as a valid answer.
String? sprPreviewTex(String input) {
  if (parseSprAnswer(input) is! SprValid) return null;
  final s = input.trim();
  final sign = s.startsWith('-') ? '-' : '';
  final body = s.substring(sign.length);
  final slash = body.indexOf('/');
  if (slash == -1) return '$sign$body';
  return '$sign\\dfrac{${body.substring(0, slash)}}'
      '{${body.substring(slash + 1)}}';
}
