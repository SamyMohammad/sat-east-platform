import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_palette.dart';

/// Semantic colours shared by every app surface.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.raised,
    required this.line,
    required this.lineStrong,
    required this.ink,
    required this.inkSecondary,
    required this.inkTertiary,
    required this.brand,
    required this.onBrand,
    required this.brandWash,
    required this.brandLine,
    required this.correct,
    required this.correctWash,
    required this.correctLine,
    required this.incorrect,
    required this.incorrectWash,
    required this.incorrectLine,
    required this.warm,
    required this.warmLine,
    required this.warmInk,
    required this.warning,
    required this.warningWash,
    required this.scrim,
    required this.shadow,
    required this.examBar,
    required this.onExamBar,
    required this.onExamBarVariant,
    required this.examBarRule,
    required this.examBarPrimary,
    required this.examBarWarning,
    required this.danger,
    required this.onDanger,
    required this.dangerHover,
  });

  static const light = AppColors(
    background: AppLightPalette.background,
    surface: AppLightPalette.surface,
    raised: AppLightPalette.raised,
    line: AppLightPalette.line,
    lineStrong: AppLightPalette.lineStrong,
    ink: AppLightPalette.ink,
    inkSecondary: AppLightPalette.inkSecondary,
    inkTertiary: AppLightPalette.inkTertiary,
    brand: AppLightPalette.brand,
    onBrand: AppLightPalette.onBrand,
    brandWash: AppLightPalette.brandWash,
    brandLine: AppLightPalette.brandLine,
    correct: AppLightPalette.correct,
    correctWash: AppLightPalette.correctWash,
    correctLine: AppLightPalette.correctLine,
    incorrect: AppLightPalette.incorrect,
    incorrectWash: AppLightPalette.incorrectWash,
    incorrectLine: AppLightPalette.incorrectLine,
    warm: AppLightPalette.warm,
    warmLine: AppLightPalette.warmLine,
    warmInk: AppLightPalette.warmInk,
    warning: AppLightPalette.warning,
    warningWash: AppLightPalette.warningWash,
    scrim: AppLightPalette.scrim,
    shadow: AppLightPalette.shadow,
    examBar: AppLightPalette.examBar,
    onExamBar: AppLightPalette.onExamBar,
    onExamBarVariant: AppLightPalette.onExamBarVariant,
    examBarRule: AppLightPalette.examBarRule,
    examBarPrimary: AppLightPalette.examBarPrimary,
    examBarWarning: AppLightPalette.examBarWarning,
    danger: AppLightPalette.danger,
    onDanger: AppLightPalette.onDanger,
    dangerHover: AppLightPalette.dangerHover,
  );

  static const dark = AppColors(
    background: AppDarkPalette.background,
    surface: AppDarkPalette.surface,
    raised: AppDarkPalette.raised,
    line: AppDarkPalette.line,
    lineStrong: AppDarkPalette.lineStrong,
    ink: AppDarkPalette.ink,
    inkSecondary: AppDarkPalette.inkSecondary,
    inkTertiary: AppDarkPalette.inkTertiary,
    brand: AppDarkPalette.brand,
    onBrand: AppDarkPalette.onBrand,
    brandWash: AppDarkPalette.brandWash,
    brandLine: AppDarkPalette.brandLine,
    correct: AppDarkPalette.correct,
    correctWash: AppDarkPalette.correctWash,
    correctLine: AppDarkPalette.correctLine,
    incorrect: AppDarkPalette.incorrect,
    incorrectWash: AppDarkPalette.incorrectWash,
    incorrectLine: AppDarkPalette.incorrectLine,
    warm: AppDarkPalette.warm,
    warmLine: AppDarkPalette.warmLine,
    warmInk: AppDarkPalette.warmInk,
    warning: AppDarkPalette.warning,
    warningWash: AppDarkPalette.warningWash,
    scrim: AppDarkPalette.scrim,
    shadow: AppDarkPalette.shadow,
    examBar: AppDarkPalette.examBar,
    onExamBar: AppDarkPalette.onExamBar,
    onExamBarVariant: AppDarkPalette.onExamBarVariant,
    examBarRule: AppDarkPalette.examBarRule,
    examBarPrimary: AppDarkPalette.examBarPrimary,
    examBarWarning: AppDarkPalette.examBarWarning,
    danger: AppDarkPalette.danger,
    onDanger: AppDarkPalette.onDanger,
    dangerHover: AppDarkPalette.dangerHover,
  );

  final Color background;
  final Color surface;
  final Color raised;
  final Color line;
  final Color lineStrong;
  final Color ink;
  final Color inkSecondary;
  final Color inkTertiary;
  final Color brand;
  final Color onBrand;
  final Color brandWash;
  final Color brandLine;
  final Color correct;
  final Color correctWash;
  final Color correctLine;
  final Color incorrect;
  final Color incorrectWash;
  final Color incorrectLine;
  final Color warm;
  final Color warmLine;
  final Color warmInk;
  final Color warning;
  final Color warningWash;
  final Color scrim;
  final Color shadow;
  final Color examBar;
  final Color onExamBar;
  final Color onExamBarVariant;
  final Color examBarRule;
  final Color examBarPrimary;
  final Color examBarWarning;
  final Color danger;
  final Color onDanger;
  final Color dangerHover;

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? raised,
    Color? line,
    Color? lineStrong,
    Color? ink,
    Color? inkSecondary,
    Color? inkTertiary,
    Color? brand,
    Color? onBrand,
    Color? brandWash,
    Color? brandLine,
    Color? correct,
    Color? correctWash,
    Color? correctLine,
    Color? incorrect,
    Color? incorrectWash,
    Color? incorrectLine,
    Color? warm,
    Color? warmLine,
    Color? warmInk,
    Color? warning,
    Color? warningWash,
    Color? scrim,
    Color? shadow,
    Color? examBar,
    Color? onExamBar,
    Color? onExamBarVariant,
    Color? examBarRule,
    Color? examBarPrimary,
    Color? examBarWarning,
    Color? danger,
    Color? onDanger,
    Color? dangerHover,
  }) => AppColors(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    raised: raised ?? this.raised,
    line: line ?? this.line,
    lineStrong: lineStrong ?? this.lineStrong,
    ink: ink ?? this.ink,
    inkSecondary: inkSecondary ?? this.inkSecondary,
    inkTertiary: inkTertiary ?? this.inkTertiary,
    brand: brand ?? this.brand,
    onBrand: onBrand ?? this.onBrand,
    brandWash: brandWash ?? this.brandWash,
    brandLine: brandLine ?? this.brandLine,
    correct: correct ?? this.correct,
    correctWash: correctWash ?? this.correctWash,
    correctLine: correctLine ?? this.correctLine,
    incorrect: incorrect ?? this.incorrect,
    incorrectWash: incorrectWash ?? this.incorrectWash,
    incorrectLine: incorrectLine ?? this.incorrectLine,
    warm: warm ?? this.warm,
    warmLine: warmLine ?? this.warmLine,
    warmInk: warmInk ?? this.warmInk,
    warning: warning ?? this.warning,
    warningWash: warningWash ?? this.warningWash,
    scrim: scrim ?? this.scrim,
    shadow: shadow ?? this.shadow,
    examBar: examBar ?? this.examBar,
    onExamBar: onExamBar ?? this.onExamBar,
    onExamBarVariant: onExamBarVariant ?? this.onExamBarVariant,
    examBarRule: examBarRule ?? this.examBarRule,
    examBarPrimary: examBarPrimary ?? this.examBarPrimary,
    examBarWarning: examBarWarning ?? this.examBarWarning,
    danger: danger ?? this.danger,
    onDanger: onDanger ?? this.onDanger,
    dangerHover: dangerHover ?? this.dangerHover,
  );

  @override
  AppColors lerp(covariant ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      line: Color.lerp(line, other.line, t)!,
      lineStrong: Color.lerp(lineStrong, other.lineStrong, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSecondary: Color.lerp(inkSecondary, other.inkSecondary, t)!,
      inkTertiary: Color.lerp(inkTertiary, other.inkTertiary, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      brandWash: Color.lerp(brandWash, other.brandWash, t)!,
      brandLine: Color.lerp(brandLine, other.brandLine, t)!,
      correct: Color.lerp(correct, other.correct, t)!,
      correctWash: Color.lerp(correctWash, other.correctWash, t)!,
      correctLine: Color.lerp(correctLine, other.correctLine, t)!,
      incorrect: Color.lerp(incorrect, other.incorrect, t)!,
      incorrectWash: Color.lerp(incorrectWash, other.incorrectWash, t)!,
      incorrectLine: Color.lerp(incorrectLine, other.incorrectLine, t)!,
      warm: Color.lerp(warm, other.warm, t)!,
      warmLine: Color.lerp(warmLine, other.warmLine, t)!,
      warmInk: Color.lerp(warmInk, other.warmInk, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningWash: Color.lerp(warningWash, other.warningWash, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      examBar: Color.lerp(examBar, other.examBar, t)!,
      onExamBar: Color.lerp(onExamBar, other.onExamBar, t)!,
      onExamBarVariant: Color.lerp(
        onExamBarVariant,
        other.onExamBarVariant,
        t,
      )!,
      examBarRule: Color.lerp(examBarRule, other.examBarRule, t)!,
      examBarPrimary: Color.lerp(examBarPrimary, other.examBarPrimary, t)!,
      examBarWarning: Color.lerp(examBarWarning, other.examBarWarning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      onDanger: Color.lerp(onDanger, other.onDanger, t)!,
      dangerHover: Color.lerp(dangerHover, other.dangerHover, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}

abstract final class AppSchemes {
  static const light = ColorScheme(
    brightness: Brightness.light,
    primary: AppLightPalette.brand,
    onPrimary: AppLightPalette.onBrand,
    primaryContainer: AppLightPalette.brandWash,
    onPrimaryContainer: AppLightPalette.brand,
    secondary: AppLightPalette.inkSecondary,
    onSecondary: AppLightPalette.background,
    secondaryContainer: AppLightPalette.surface,
    onSecondaryContainer: AppLightPalette.ink,
    tertiary: AppLightPalette.warmInk,
    onTertiary: AppLightPalette.background,
    tertiaryContainer: AppLightPalette.warm,
    onTertiaryContainer: AppLightPalette.warmInk,
    error: AppLightPalette.incorrect,
    onError: AppLightPalette.background,
    errorContainer: AppLightPalette.incorrectWash,
    onErrorContainer: AppLightPalette.incorrect,
    surface: AppLightPalette.background,
    onSurface: AppLightPalette.ink,
    onSurfaceVariant: AppLightPalette.inkSecondary,
    surfaceContainerLowest: AppLightPalette.background,
    surfaceContainerLow: AppLightPalette.surface,
    surfaceContainer: AppLightPalette.surface,
    surfaceContainerHigh: AppLightPalette.raised,
    surfaceContainerHighest: AppLightPalette.raised,
    outline: AppLightPalette.lineStrong,
    outlineVariant: AppLightPalette.line,
    inverseSurface: AppLightPalette.ink,
    onInverseSurface: AppLightPalette.background,
    shadow: AppLightPalette.shadow,
    scrim: AppLightPalette.scrim,
    inversePrimary: AppDarkPalette.brand,
    surfaceTint: Colors.transparent,
  );

  static const dark = ColorScheme(
    brightness: Brightness.dark,
    primary: AppDarkPalette.brand,
    onPrimary: AppDarkPalette.onBrand,
    primaryContainer: AppDarkPalette.brandWash,
    onPrimaryContainer: AppDarkPalette.brand,
    secondary: AppDarkPalette.inkSecondary,
    onSecondary: AppDarkPalette.background,
    secondaryContainer: AppDarkPalette.surface,
    onSecondaryContainer: AppDarkPalette.ink,
    tertiary: AppDarkPalette.warmInk,
    onTertiary: AppDarkPalette.background,
    tertiaryContainer: AppDarkPalette.warm,
    onTertiaryContainer: AppDarkPalette.warmInk,
    error: AppDarkPalette.incorrect,
    onError: AppDarkPalette.background,
    errorContainer: AppDarkPalette.incorrectWash,
    onErrorContainer: AppDarkPalette.incorrect,
    surface: AppDarkPalette.background,
    onSurface: AppDarkPalette.ink,
    onSurfaceVariant: AppDarkPalette.inkSecondary,
    surfaceContainerLowest: AppDarkPalette.background,
    surfaceContainerLow: AppDarkPalette.surface,
    surfaceContainer: AppDarkPalette.surface,
    surfaceContainerHigh: AppDarkPalette.raised,
    surfaceContainerHighest: AppDarkPalette.raised,
    outline: AppDarkPalette.lineStrong,
    outlineVariant: AppDarkPalette.line,
    inverseSurface: AppDarkPalette.ink,
    onInverseSurface: AppDarkPalette.background,
    shadow: AppDarkPalette.shadow,
    scrim: AppDarkPalette.scrim,
    inversePrimary: AppLightPalette.brand,
    surfaceTint: Colors.transparent,
  );
}
