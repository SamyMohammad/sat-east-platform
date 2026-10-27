import 'package:flutter/material.dart';

abstract final class AppFonts {
  static const String sans = 'Lexend';
}

abstract final class AppType {
  static const double mathScale = 1.21;

  /// Form field label above the value.
  static const double fieldLabelSize = 13;

  static const TextStyle stem = TextStyle(
    fontFamily: AppFonts.sans,
    fontSize: 22,
    height: 1.5,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.22,
  );
  static const TextStyle stemCompact = TextStyle(
    fontFamily: AppFonts.sans,
    fontSize: 19,
    height: 1.5,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.19,
  );
  static const TextStyle count = TextStyle(
    fontFamily: AppFonts.sans,
    fontSize: 13,
    height: 20 / 13,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const TextStyle timer = TextStyle(
    fontFamily: AppFonts.sans,
    fontSize: 20,
    height: 24 / 20,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static TextTheme textTheme() => const TextTheme(
    displayLarge: TextStyle(
      fontSize: 57,
      height: 64 / 57,
      fontWeight: FontWeight.w400,
    ),
    displayMedium: TextStyle(
      fontSize: 45,
      height: 52 / 45,
      fontWeight: FontWeight.w400,
    ),
    displaySmall: TextStyle(
      fontSize: 36,
      height: 44 / 36,
      fontWeight: FontWeight.w400,
    ),
    headlineLarge: TextStyle(
      fontSize: 32,
      height: 40 / 32,
      fontWeight: FontWeight.w600,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      height: 36 / 28,
      fontWeight: FontWeight.w600,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      height: 32 / 24,
      fontWeight: FontWeight.w600,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      height: 30 / 22,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w600,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w400,
    ),
    bodyMedium: TextStyle(
      fontSize: 15,
      height: 24 / 15,
      fontWeight: FontWeight.w400,
    ),
    bodySmall: TextStyle(
      fontSize: 13,
      height: 20 / 13,
      fontWeight: FontWeight.w400,
    ),
    labelLarge: TextStyle(
      fontSize: 13,
      height: 20 / 13,
      fontWeight: FontWeight.w600,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w600,
    ),
    labelSmall: TextStyle(
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w600,
    ),
  );
}
