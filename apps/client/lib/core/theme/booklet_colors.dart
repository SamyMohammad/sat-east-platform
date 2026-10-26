import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_palette.dart';

/// Deprecated shim: use App* tokens.
abstract final class BookletSchemes {
  static const ColorScheme light = AppSchemes.light;
  static const ColorScheme dark = AppSchemes.dark;
}

/// Deprecated shim: use App* tokens.
@immutable
class BookletColors extends ThemeExtension<BookletColors> {
  const BookletColors({
    required this.frameTint,
    required this.inkDisabled,
    required this.primaryHover,
    required this.greenTick,
    required this.greenTickContainer,
    required this.highlighter,
    required this.onHighlighter,
    required this.warning,
    required this.warningContainer,
    required this.info,
    required this.infoContainer,
    required this.examBar,
    required this.onExamBar,
    required this.onExamBarVariant,
    required this.examBarRule,
    required this.examBarPrimary,
    required this.examBarWarning,
    required this.scrim,
    required this.overlayShadow,
  });

  static const light = BookletColors(
    frameTint: AppLightPalette.surface,
    inkDisabled: AppLightPalette.inkTertiary,
    primaryHover: AppLightPalette.brand,
    greenTick: AppLightPalette.correct,
    greenTickContainer: AppLightPalette.correctWash,
    highlighter: AppLightPalette.brandWash,
    onHighlighter: AppLightPalette.ink,
    warning: AppLightPalette.warning,
    warningContainer: AppLightPalette.warningWash,
    info: AppLightPalette.brand,
    infoContainer: AppLightPalette.brandWash,
    examBar: AppLightPalette.examBar,
    onExamBar: AppLightPalette.onExamBar,
    onExamBarVariant: AppLightPalette.onExamBarVariant,
    examBarRule: AppLightPalette.examBarRule,
    examBarPrimary: AppLightPalette.examBarPrimary,
    examBarWarning: AppLightPalette.examBarWarning,
    scrim: AppLightPalette.scrim,
    overlayShadow: AppLightPalette.shadow,
  );

  /// The exam bar uses the same dark surface in both themes.
  static const dark = BookletColors(
    frameTint: AppDarkPalette.surface,
    inkDisabled: AppDarkPalette.inkTertiary,
    primaryHover: AppDarkPalette.brand,
    greenTick: AppDarkPalette.correct,
    greenTickContainer: AppDarkPalette.correctWash,
    highlighter: AppDarkPalette.brandWash,
    onHighlighter: AppDarkPalette.ink,
    warning: AppDarkPalette.warning,
    warningContainer: AppDarkPalette.warningWash,
    info: AppDarkPalette.brand,
    infoContainer: AppDarkPalette.brandWash,
    examBar: AppDarkPalette.examBar,
    onExamBar: AppDarkPalette.onExamBar,
    onExamBarVariant: AppDarkPalette.onExamBarVariant,
    examBarRule: AppDarkPalette.examBarRule,
    examBarPrimary: AppDarkPalette.examBarPrimary,
    examBarWarning: AppDarkPalette.examBarWarning,
    scrim: AppDarkPalette.scrim,
    overlayShadow: AppDarkPalette.shadow,
  );

  final Color frameTint;
  final Color inkDisabled;
  final Color primaryHover;
  final Color greenTick;
  final Color greenTickContainer;
  final Color highlighter;
  final Color onHighlighter;
  final Color warning;
  final Color warningContainer;
  final Color info;
  final Color infoContainer;
  final Color examBar;
  final Color onExamBar;
  final Color onExamBarVariant;
  final Color examBarRule;
  final Color examBarPrimary;
  final Color examBarWarning;
  final Color scrim;
  final Color overlayShadow;

  @override
  BookletColors copyWith({
    Color? frameTint,
    Color? inkDisabled,
    Color? primaryHover,
    Color? greenTick,
    Color? greenTickContainer,
    Color? highlighter,
    Color? onHighlighter,
    Color? warning,
    Color? warningContainer,
    Color? info,
    Color? infoContainer,
    Color? examBar,
    Color? onExamBar,
    Color? onExamBarVariant,
    Color? examBarRule,
    Color? examBarPrimary,
    Color? examBarWarning,
    Color? scrim,
    Color? overlayShadow,
  }) {
    return BookletColors(
      frameTint: frameTint ?? this.frameTint,
      inkDisabled: inkDisabled ?? this.inkDisabled,
      primaryHover: primaryHover ?? this.primaryHover,
      greenTick: greenTick ?? this.greenTick,
      greenTickContainer: greenTickContainer ?? this.greenTickContainer,
      highlighter: highlighter ?? this.highlighter,
      onHighlighter: onHighlighter ?? this.onHighlighter,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
      examBar: examBar ?? this.examBar,
      onExamBar: onExamBar ?? this.onExamBar,
      onExamBarVariant: onExamBarVariant ?? this.onExamBarVariant,
      examBarRule: examBarRule ?? this.examBarRule,
      examBarPrimary: examBarPrimary ?? this.examBarPrimary,
      examBarWarning: examBarWarning ?? this.examBarWarning,
      scrim: scrim ?? this.scrim,
      overlayShadow: overlayShadow ?? this.overlayShadow,
    );
  }

  @override
  BookletColors lerp(covariant ThemeExtension<BookletColors>? other, double t) {
    if (other is! BookletColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return BookletColors(
      frameTint: c(frameTint, other.frameTint),
      inkDisabled: c(inkDisabled, other.inkDisabled),
      primaryHover: c(primaryHover, other.primaryHover),
      greenTick: c(greenTick, other.greenTick),
      greenTickContainer: c(greenTickContainer, other.greenTickContainer),
      highlighter: c(highlighter, other.highlighter),
      onHighlighter: c(onHighlighter, other.onHighlighter),
      warning: c(warning, other.warning),
      warningContainer: c(warningContainer, other.warningContainer),
      info: c(info, other.info),
      infoContainer: c(infoContainer, other.infoContainer),
      examBar: c(examBar, other.examBar),
      onExamBar: c(onExamBar, other.onExamBar),
      onExamBarVariant: c(onExamBarVariant, other.onExamBarVariant),
      examBarRule: c(examBarRule, other.examBarRule),
      examBarPrimary: c(examBarPrimary, other.examBarPrimary),
      examBarWarning: c(examBarWarning, other.examBarWarning),
      scrim: c(scrim, other.scrim),
      overlayShadow: c(overlayShadow, other.overlayShadow),
    );
  }
}

extension BookletThemeContext on BuildContext {
  /// Booklet roles of the current theme. Set by `AppTheme`.
  BookletColors get booklet => Theme.of(this).extension<BookletColors>()!;
}
