import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/core/theme/app_type.dart';

void main() {
  for (final (name, theme, scheme, colors) in [
    ('light', AppTheme.light(), AppSchemes.light, AppColors.light),
    ('dark', AppTheme.dark(), AppSchemes.dark, AppColors.dark),
  ]) {
    test('F-4: $name theme uses the app scheme and extension', () {
      expect(theme.colorScheme, scheme);
      expect(theme.extension<AppColors>(), colors);
    });
  }

  test('redesign: body style is 16/24 regular Lexend', () {
    final stem = AppTheme.light().textTheme.bodyLarge!;
    expect(stem.fontSize, 16);
    expect(stem.height, closeTo(24 / 16, 1e-9));
    expect(stem.fontWeight, FontWeight.w400);
    expect(AppFonts.sans, 'Lexend');
    expect(AppFonts.sans, AppFonts.sans);
    expect(stem.fontFamily, 'Lexend');
  });

  test('F-4: buttons meet the 48 px touch target', () {
    final style = AppTheme.light().filledButtonTheme.style!;
    expect(style.minimumSize!.resolve({})!.height, 48);
  });

  test('F-4: no ripple (the app has no splash)', () {
    expect(AppTheme.light().splashFactory, NoSplash.splashFactory);
  });

  test('redesign: overlays have a soft shadow in both themes', () {
    expect(AppTheme.dark().dialogTheme.elevation, greaterThan(0));
    expect(AppTheme.light().dialogTheme.elevation, greaterThan(0));
  });

  test('redesign: component roles and geometry in both themes', () {
    for (final (theme, colors) in [
      (AppTheme.light(), AppColors.light),
      (AppTheme.dark(), AppColors.dark),
    ]) {
      expect(theme.extension<AppColors>(), colors);
      final primaryButton = theme.filledButtonTheme.style!;
      expect(primaryButton.elevation!.resolve({}), 2);
      expect(primaryButton.shadowColor!.resolve({}), colors.shadow);
      expect(primaryButton.side!.resolve({}), BorderSide.none);
      expect(
        primaryButton.side!.resolve({WidgetState.focused}),
        BorderSide(color: colors.brandLine, width: AppStroke.focusRing),
      );
      expect(theme.scaffoldBackgroundColor, colors.background);
      expect(
        theme.inputDecorationTheme.focusedBorder!.borderSide,
        BorderSide(color: colors.brandLine, width: AppStroke.focusRing),
      );
      expect(
        (theme.inputDecorationTheme.border! as OutlineInputBorder).borderRadius,
        BorderRadius.circular(AppRadius.control),
      );
      expect(
        (theme.cardTheme.shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(AppRadius.card),
      );
      expect(
        (theme.dialogTheme.shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(AppRadius.overlay),
      );
      expect(theme.chipTheme.shape, isA<StadiumBorder>());
      expect(
        theme.progressIndicatorTheme.linearMinHeight,
        AppSize.progressThickness,
      );
      expect(theme.navigationBarTheme.backgroundColor, colors.surface);
      expect(theme.navigationRailTheme.backgroundColor, colors.surface);
    }
  });

  test('redesign: full type scale and responsive stem', () {
    final text = AppType.textTheme();
    expect([
      text.displayLarge,
      text.displayMedium,
      text.displaySmall,
      text.headlineLarge,
      text.headlineMedium,
      text.headlineSmall,
      text.titleLarge,
      text.titleMedium,
      text.titleSmall,
      text.bodyLarge,
      text.bodyMedium,
      text.bodySmall,
      text.labelLarge,
      text.labelMedium,
      text.labelSmall,
    ], everyElement(isNotNull));
    expect(AppType.stem.fontSize, 22);
    expect(AppType.stemCompact.fontSize, 19);
    expect(AppType.stem.fontWeight, FontWeight.w500);
    expect(
      AppType.count.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });

  test('F-4: timer uses tabular figures', () {
    expect(
      AppType.timer.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });

  testWidgets('F-4: context.appColors resolves under AppTheme', (tester) async {
    late AppColors appColors;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            appColors = context.appColors;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(appColors, AppColors.light);
  });
}
