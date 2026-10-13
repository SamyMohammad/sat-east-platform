// test/core/theme/app_theme_test.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/core/theme/booklet_colors.dart';
import 'package:sat_east_client/core/theme/booklet_type.dart';

void main() {
  for (final (name, theme, scheme, booklet) in [
    ('light', AppTheme.light(), BookletSchemes.light, BookletColors.light),
    ('dark', AppTheme.dark(), BookletSchemes.dark, BookletColors.dark),
  ]) {
    test('F-4: $name theme uses the booklet scheme and extension', () {
      expect(theme.colorScheme, scheme);
      expect(theme.extension<BookletColors>(), booklet);
    });
  }

  test('F-4: question stem style is 18/28 regular Noto Sans', () {
    final stem = AppTheme.light().textTheme.bodyLarge!;
    expect(stem.fontSize, 18);
    expect(stem.height, closeTo(28 / 18, 1e-9));
    expect(stem.fontWeight, FontWeight.w400);
    expect(stem.fontFamily, BookletFonts.sans);
  });

  test('F-4: buttons meet the 48 px touch target', () {
    final style = AppTheme.light().filledButtonTheme.style!;
    expect(style.minimumSize!.resolve({})!.height, 48);
  });

  test('F-4: no ripple (booklet has no splash)', () {
    expect(AppTheme.light().splashFactory, NoSplash.splashFactory);
  });

  test('F-4: dark overlays have no elevation shadow', () {
    expect(AppTheme.dark().dialogTheme.elevation, 0);
    expect(AppTheme.light().dialogTheme.elevation, greaterThan(0));
  });

  test('F-4: timer uses tabular figures', () {
    expect(
      BookletType.timer.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });

  test('F-4: standard density keeps 48 px buttons on desktop/web', () {
    // Web on a desktop browser reports a desktop platform → compact default.
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(AppTheme.light().visualDensity, VisualDensity.standard);
    expect(AppTheme.dark().visualDensity, VisualDensity.standard);
  });

  test('F-4: dialogs and sheets use the surface role, not the page', () {
    expect(
      AppTheme.dark().dialogTheme.backgroundColor,
      BookletSchemes.dark.surfaceContainerLow,
    );
    expect(
      AppTheme.dark().bottomSheetTheme.backgroundColor,
      BookletSchemes.dark.surfaceContainerLow,
    );
    expect(
      AppTheme.light().dialogTheme.backgroundColor,
      BookletSchemes.light.surfaceContainerLow,
    );
    expect(
      AppTheme.light().bottomSheetTheme.backgroundColor,
      BookletSchemes.light.surfaceContainerLow,
    );
  });

  test('F-4: dialog title is the title style with a 1 px rule border', () {
    final d = AppTheme.light().dialogTheme;
    expect(d.titleTextStyle!.fontSize, 20);
    final shape = d.shape! as RoundedRectangleBorder;
    expect(shape.side.color, BookletSchemes.light.outlineVariant);
    expect(shape.side.width, 1);
  });

  test('F-4: every TextTheme role uses Noto Sans and the ink color', () {
    for (final (theme, scheme) in [
      (AppTheme.light(), BookletSchemes.light),
      (AppTheme.dark(), BookletSchemes.dark),
    ]) {
      final text = theme.textTheme;
      final roles = <String, TextStyle?>{
        'displayLarge': text.displayLarge,
        'displayMedium': text.displayMedium,
        'displaySmall': text.displaySmall,
        'headlineLarge': text.headlineLarge,
        'headlineMedium': text.headlineMedium,
        'headlineSmall': text.headlineSmall,
        'titleLarge': text.titleLarge,
        'titleMedium': text.titleMedium,
        'titleSmall': text.titleSmall,
        'bodyLarge': text.bodyLarge,
        'bodyMedium': text.bodyMedium,
        'bodySmall': text.bodySmall,
        'labelLarge': text.labelLarge,
        'labelMedium': text.labelMedium,
        'labelSmall': text.labelSmall,
      };
      for (final MapEntry(key: name, value: style) in roles.entries) {
        expect(style, isNotNull, reason: name);
        expect(style!.fontFamily, BookletFonts.sans, reason: name);
        expect(style.color, scheme.onSurface, reason: name);
        expect(
          style.fontFamilyFallback,
          contains(BookletFonts.arabic),
          reason: name,
        );
      }
    }
  });

  test('F-4: Arabic style keeps letter spacing at 0', () {
    expect(BookletType.arabic.letterSpacing, 0);
  });

  testWidgets('F-4: context.booklet resolves under AppTheme', (tester) async {
    late BookletColors resolved;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            resolved = context.booklet;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(resolved, BookletColors.light);
  });
}
