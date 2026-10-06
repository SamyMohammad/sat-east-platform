import 'package:flutter/material.dart';

/// Placeholder theme; real tokens come with the design system (F-4).
abstract final class AppTheme {
  static ThemeData light() => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E5EFF)),
  );

  static ThemeData dark() => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF1E5EFF),
      brightness: Brightness.dark,
    ),
  );
}
