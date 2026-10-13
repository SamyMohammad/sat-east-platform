import 'package:flutter/material.dart';

/// Bundled families (pubspec `fonts:`).
abstract final class BookletFonts {
  static const String sans = 'NotoSans';
  static const String arabic = 'NotoSansArabic';
}

/// Type scale from Foundations.dc.html "type.*".
/// `labelSmall` is the caption style; callers upper-case its text.
abstract final class BookletType {
  /// Math renders at 1.21 em of the surrounding text (Foundations).
  static const double mathScale = 1.21;

  static TextTheme textTheme() => const TextTheme(
    displaySmall: TextStyle(
      fontSize: 40,
      height: 48 / 40,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.8,
    ),
    headlineSmall: TextStyle(
      fontSize: 28,
      height: 36 / 28,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.28,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      height: 28 / 20,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
    bodyLarge: TextStyle(
      fontSize: 18,
      height: 28 / 18,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
    ),
    bodyMedium: TextStyle(
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.14,
    ),
    labelSmall: TextStyle(
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.72,
    ),
  );

  /// Exam clock: 20/24, tabular figures so digits do not jump.
  static const TextStyle timer = TextStyle(
    fontFamily: BookletFonts.sans,
    fontSize: 20,
    height: 24 / 20,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Arabic body: 16/28 (decision in spec), Latin falls back to Noto Sans.
  static const TextStyle arabic = TextStyle(
    fontFamily: BookletFonts.arabic,
    fontFamilyFallback: [BookletFonts.sans],
    fontSize: 16,
    height: 28 / 16,
    fontWeight: FontWeight.w400,
  );
}
