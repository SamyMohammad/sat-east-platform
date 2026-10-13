// test/core/theme/app_theme_test.dart
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
