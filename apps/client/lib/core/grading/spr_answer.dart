/// SPR (student-produced response) input rules — GRD-02, docs/08 §6.
///
/// Mirrors `private.spr_parse` on the server. Used for input validation and
/// the Answer Preview only; grading happens server-side (keys never reach the
/// client).
library;

/// Maximum characters for a non-negative answer (official SAT format rule).
const int sprMaxLength = 5;

/// Maximum characters when the answer starts with `-`.
const int sprMaxLengthNegative = 6;

/// Why an SPR input cannot be submitted as typed.
enum SprInvalidReason { empty, tooLong, mixedNumber, zeroDenominator, format }

/// A parsed SPR input.
sealed class SprAnswer {
  const SprAnswer();
}

/// A valid input, as a reduced fraction ([denominator] > 0).
final class SprValid extends SprAnswer {
  const SprValid(this.numerator, this.denominator);

  final BigInt numerator;
  final BigInt denominator;
}

/// An input the grader would reject.
final class SprInvalid extends SprAnswer {
  const SprInvalid(this.reason);

  final SprInvalidReason reason;
}

final _fraction = RegExp(r'^(-?)(\d+)/(\d+)$');
final _decimal = RegExp(r'^(-?)(\d*)(?:\.(\d*))?$');
final _mixed = RegExp(r'^-?\d+\s+\d+/\d+$');
final _outerSpaces = RegExp(r'^ +| +$');

/// Parses [input] with the same rules as the server grader.
SprAnswer parseSprAnswer(String input) {
  // Trim ASCII spaces only, exactly like Postgres btrim on the server.
  final s = input.replaceAll(_outerSpaces, '');
  if (s.isEmpty) return const SprInvalid(SprInvalidReason.empty);
  if (_mixed.hasMatch(s)) return const SprInvalid(SprInvalidReason.mixedNumber);
  final max = s.startsWith('-') ? sprMaxLengthNegative : sprMaxLength;
  if (s.length > max) return const SprInvalid(SprInvalidReason.tooLong);

  final fraction = _fraction.firstMatch(s);
  if (fraction != null) {
    final denominator = BigInt.parse(fraction[3]!);
    if (denominator == BigInt.zero) {
      return const SprInvalid(SprInvalidReason.zeroDenominator);
    }
    return _reduced(fraction[1]!, BigInt.parse(fraction[2]!), denominator);
  }

  final decimal = _decimal.firstMatch(s);
  final whole = decimal?[2] ?? '';
  final digits = decimal?[3] ?? '';
  if (decimal == null || (whole.isEmpty && digits.isEmpty)) {
    return const SprInvalid(SprInvalidReason.format);
  }
  return _reduced(
    decimal[1]!,
    BigInt.parse('${whole.isEmpty ? '0' : whole}$digits'),
    BigInt.from(10).pow(digits.length),
  );
}

SprValid _reduced(String sign, BigInt magnitude, BigInt denominator) {
  final g = magnitude.gcd(denominator);
  final numerator = magnitude ~/ g;
  return SprValid(sign == '-' ? -numerator : numerator, denominator ~/ g);
}
