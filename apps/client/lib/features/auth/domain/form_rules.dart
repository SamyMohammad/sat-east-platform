/// Sign-up form checks. UX only: the server re-validates (CLAUDE.md rule 2).
abstract final class FormRules {
  static const int minPasswordLength = 8;

  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final _digit = RegExp('[0-9]');
  static final _letter = RegExp('[A-Za-z]');

  static bool looksLikeEmail(String value) => _email.hasMatch(value.trim());

  static PasswordRules passwordRules(String password) => PasswordRules(
    length: password.length,
    hasMinLength: password.length >= minPasswordLength,
    hasNumber: _digit.hasMatch(password),
    hasLetter: _letter.hasMatch(password),
  );
}

final class PasswordRules {
  const PasswordRules({
    required this.length,
    required this.hasMinLength,
    required this.hasNumber,
    required this.hasLetter,
  });

  final int length;
  final bool hasMinLength;
  final bool hasNumber;
  final bool hasLetter;

  bool get allMet => hasMinLength && hasNumber && hasLetter;
}
