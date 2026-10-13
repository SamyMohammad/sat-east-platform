import 'package:flutter/material.dart';
import 'package:sat_east_client/core/theme/booklet_colors.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/core/theme/booklet_type.dart';

/// "The Teacher's Booklet" theme (F-4). Tokens: docs/design/claude-design-export.
abstract final class AppTheme {
  static ThemeData light() => _build(BookletSchemes.light, BookletColors.light);

  static ThemeData dark() => _build(BookletSchemes.dark, BookletColors.dark);

  static ThemeData _build(ColorScheme scheme, BookletColors booklet) {
    final text = BookletType.textTheme().apply(
      fontFamily: BookletFonts.sans,
      fontFamilyFallback: const [BookletFonts.arabic],
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    const radiusXs = BorderRadius.all(Radius.circular(BookletRadius.xs));
    const radiusSm = BorderRadius.all(Radius.circular(BookletRadius.sm));
    const radiusMd = Radius.circular(BookletRadius.md);
    const buttonShape = RoundedRectangleBorder(borderRadius: radiusSm);
    const minButton = Size(64, BookletSize.touchTarget);
    const buttonPadding = EdgeInsets.symmetric(horizontal: BookletSpace.s6);
    // One shadow in light (dialog, sheet, snackbar); none in dark.
    final overlayElevation = scheme.brightness == Brightness.light ? 2.0 : 0.0;
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          // Default radius is 4 = BookletRadius.sm.
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,
      fontFamily: BookletFonts.sans,
      fontFamilyFallback: const [BookletFonts.arabic],
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: NoSplash.splashFactory,
      extensions: [booklet],
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: minButton,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: minButton,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: text.labelLarge,
          side: BorderSide(color: scheme.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: minButton,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(BookletSize.touchTarget),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: border(scheme.outline),
        enabledBorder: border(scheme.outline),
        focusedBorder: border(scheme.primary, 2),
        errorBorder: border(scheme.error),
        focusedErrorBorder: border(scheme.error, 2),
        disabledBorder: border(booklet.inkDisabled),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        surfaceTintColor: scheme.surfaceTint,
        shape: RoundedRectangleBorder(
          borderRadius: radiusXs,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: scheme.surfaceTint,
        elevation: overlayElevation,
        shadowColor: booklet.overlayShadow,
        barrierColor: booklet.scrim,
        titleTextStyle: text.titleLarge,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(radiusMd),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: scheme.surfaceTint,
        elevation: overlayElevation,
        modalElevation: overlayElevation,
        shadowColor: booklet.overlayShadow,
        modalBarrierColor: booklet.scrim,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: radiusMd),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: overlayElevation,
        shape: const RoundedRectangleBorder(borderRadius: radiusSm),
      ),
    );
  }
}
