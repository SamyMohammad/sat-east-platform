import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/theme/app_colors.dart';

void main() {
  for (final (name, colors) in [
    ('light', AppColors.light),
    ('dark', AppColors.dark),
  ]) {
    test('contrast_meets_AA_$name', () {
      final pairs = <String, (Color, Color)>{
        'ink/background': (colors.ink, colors.background),
        'ink/surface': (colors.ink, colors.surface),
        'ink/raised': (colors.ink, colors.raised),
        'inkSecondary/surface': (colors.inkSecondary, colors.surface),
        'inkSecondary/raised': (colors.inkSecondary, colors.raised),
        'inkTertiary/surface': (colors.inkTertiary, colors.surface),
        'inkTertiary/raised': (colors.inkTertiary, colors.raised),
        'onBrand/brand': (colors.onBrand, colors.brand),
        'brand/brandWash': (colors.brand, colors.brandWash),
        'correct/correctWash': (colors.correct, colors.correctWash),
        'incorrect/incorrectWash': (colors.incorrect, colors.incorrectWash),
        'warmInk/warm': (colors.warmInk, colors.warm),
        'warning/warningWash': (colors.warning, colors.warningWash),
        'onExamBar/examBar': (colors.onExamBar, colors.examBar),
        'onExamBarVariant/examBar': (colors.onExamBarVariant, colors.examBar),
        'examBarPrimary/examBar': (colors.examBarPrimary, colors.examBar),
        'examBarWarning/examBar': (colors.examBarWarning, colors.examBar),
      };
      for (final entry in pairs.entries) {
        final (foreground, background) = entry.value;
        final a = foreground.computeLuminance();
        final b = background.computeLuminance();
        final ratio = ((a > b ? a : b) + 0.05) / ((a > b ? b : a) + 0.05);
        expect(ratio, greaterThanOrEqualTo(4.5), reason: entry.key);
      }
    });
  }
  test('lerp_is_total', () {
    const light = AppColors.light;
    const dark = AppColors.dark;
    expect(_roles(light.lerp(dark, 0)), _roles(light));
    expect(_roles(light.lerp(dark, 1)), _roles(dark));
    expect(_roles(light.lerp(null, 0.5)), _roles(light));
    final midpoint = _roles(light.lerp(dark, 0.5));
    for (var i = 0; i < midpoint.length; i++) {
      expect(midpoint[i], Color.lerp(_roles(light)[i], _roles(dark)[i], 0.5));
    }
  });
}

List<Color> _roles(AppColors c) => [
  c.background,
  c.surface,
  c.raised,
  c.line,
  c.lineStrong,
  c.ink,
  c.inkSecondary,
  c.inkTertiary,
  c.brand,
  c.onBrand,
  c.brandWash,
  c.brandLine,
  c.correct,
  c.correctWash,
  c.correctLine,
  c.incorrect,
  c.incorrectWash,
  c.incorrectLine,
  c.warm,
  c.warmLine,
  c.warmInk,
  c.warning,
  c.warningWash,
  c.scrim,
  c.shadow,
  c.examBar,
  c.onExamBar,
  c.onExamBarVariant,
  c.examBarRule,
  c.examBarPrimary,
  c.examBarWarning,
];
