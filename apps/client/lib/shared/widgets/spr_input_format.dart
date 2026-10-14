part of 'spr_input.dart';

/// Hint copy (MathText markup) for [value], or null. Hints are info, never
/// red (Components.dc.html §3).
String? sprHintText(String value, {SprKeyHint? keyHint}) {
  if (keyHint != null) {
    return switch (keyHint) {
      SprKeyHint.secondSlash => 'A fraction has only one slash.',
      SprKeyHint.secondDot => 'A number has only one decimal point.',
      SprKeyHint.slashAndDot => 'Use a fraction or a decimal, not both.',
    };
  }
  return switch (parseSprAnswer(value)) {
    SprInvalid(reason: SprInvalidReason.mixedNumber) =>
      "Mixed numbers aren't accepted. Enter **3/2** or **1.5**.",
    SprInvalid(reason: SprInvalidReason.tooLong) =>
      'Up to $sprMaxLength characters ($sprMaxLengthNegative with a minus '
          'sign). Try **.6666** or **2/3**.',
    SprInvalid(reason: SprInvalidReason.zeroDenominator) =>
      "A fraction can't have 0 on the bottom.",
    SprInvalid() || SprValid() => null,
  };
}

/// Normalises digits, then keeps only SPR characters. Spaces stay so the
/// mixed-number hint can show; the cap is above the grading limit so the
/// length hint can show.
final List<TextInputFormatter> sprInputFormatters = [
  TextInputFormatter.withFunction(
    (oldValue, newValue) {
      if (!newValue.composing.isCollapsed) return newValue;
      final normalized = newValue.copyWith(
        text: normalizeSprDigits(newValue.text),
      );
      final filtered = _sprCharacterFilter.formatEditUpdate(
        oldValue,
        normalized,
      );
      return _sprLengthLimit.formatEditUpdate(oldValue, filtered);
    },
  ),
];

final _sprCharacterFilter = FilteringTextInputFormatter.allow(
  RegExp(r'[0-9./\- ]'),
);
final _sprLengthLimit = LengthLimitingTextInputFormatter(sprInputMaxChars);
