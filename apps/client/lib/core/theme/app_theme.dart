import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/core/theme/app_type.dart';
import 'package:sat_east_client/core/theme/booklet_colors.dart';

/// The shared visual system, with Booklet compatibility during migration.
abstract final class AppTheme {
  static ThemeData light() =>
      _build(AppSchemes.light, AppColors.light, BookletColors.light);

  static ThemeData dark() =>
      _build(AppSchemes.dark, AppColors.dark, BookletColors.dark);

  static ThemeData _build(
    ColorScheme scheme,
    AppColors colors,
    BookletColors booklet,
  ) {
    final text = AppType.textTheme().apply(
      fontFamily: AppFonts.sans,
      fontFamilyFallback: const [AppFonts.arabic],
      bodyColor: colors.ink,
      displayColor: colors.ink,
    );
    const controlRadius = BorderRadius.all(Radius.circular(AppRadius.control));
    const cardRadius = BorderRadius.all(Radius.circular(AppRadius.card));
    const overlayRadius = Radius.circular(AppRadius.overlay);
    const buttonShape = RoundedRectangleBorder(borderRadius: controlRadius);
    const minButton = Size(64, AppSize.touchTarget);
    const buttonPadding = EdgeInsets.symmetric(horizontal: AppSpace.s6);
    const overlayElevation = 2.0;
    OutlineInputBorder border(Color color, [double width = AppStroke.thin]) =>
        OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(color: color, width: width),
        );
    final focusSide = WidgetStateBorderSide.resolveWith((states) {
      if (states.contains(WidgetState.focused)) {
        return BorderSide(color: colors.brandLine, width: AppStroke.focusRing);
      }
      return BorderSide.none;
    });
    final filledStyle = FilledButton.styleFrom(
      backgroundColor: colors.brand,
      foregroundColor: colors.onBrand,
      elevation: 2,
      shadowColor: colors.shadow,
      surfaceTintColor: Colors.transparent,
      minimumSize: minButton,
      padding: buttonPadding,
      shape: buttonShape,
      textStyle: text.labelLarge,
    );

    return ThemeData(
      colorScheme: scheme,
      fontFamily: AppFonts.sans,
      fontFamilyFallback: const [AppFonts.arabic],
      textTheme: text,
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.background,
      shadowColor: colors.shadow,
      focusColor: colors.brandLine,
      splashFactory: NoSplash.splashFactory,
      extensions: [colors, booklet],
      dividerTheme: DividerThemeData(
        color: colors.line,
        thickness: AppStroke.thin,
        space: AppStroke.thin,
      ),
      appBarTheme: AppBarThemeData(
        backgroundColor: colors.background,
        foregroundColor: colors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: filledStyle.copyWith(side: focusSide),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.brand,
          foregroundColor: colors.onBrand,
          shadowColor: colors.shadow,
          surfaceTintColor: Colors.transparent,
          elevation: 2,
          minimumSize: minButton,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: text.labelLarge,
        ).copyWith(side: focusSide),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              foregroundColor: colors.ink,
              minimumSize: minButton,
              padding: buttonPadding,
              shape: buttonShape,
              textStyle: text.labelLarge,
            ).copyWith(
              side: WidgetStateBorderSide.resolveWith(
                (states) => states.contains(WidgetState.focused)
                    ? BorderSide(
                        color: colors.brandLine,
                        width: AppStroke.focusRing,
                      )
                    : BorderSide(color: colors.lineStrong),
              ),
            ),
      ),
      textButtonTheme: TextButtonThemeData(
        style:
            TextButton.styleFrom(
              foregroundColor: colors.brand,
              minimumSize: minButton,
              padding: buttonPadding,
              shape: buttonShape,
              textStyle: text.labelLarge,
            ).copyWith(
              side: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.focused)
                    ? BorderSide(
                        color: colors.brandLine,
                        width: AppStroke.focusRing,
                      )
                    : BorderSide.none,
              ),
            ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style:
            IconButton.styleFrom(
              foregroundColor: colors.inkSecondary,
              minimumSize: const Size.square(AppSize.touchTarget),
              shape: buttonShape,
            ).copyWith(
              side: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.focused)
                    ? BorderSide(
                        color: colors.brandLine,
                        width: AppStroke.focusRing,
                      )
                    : BorderSide.none,
              ),
            ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.background,
        labelStyle: text.bodyMedium?.copyWith(color: colors.inkSecondary),
        hintStyle: text.bodyMedium?.copyWith(color: colors.inkTertiary),
        border: border(colors.lineStrong),
        enabledBorder: border(colors.lineStrong),
        focusedBorder: border(colors.brandLine, AppStroke.focusRing),
        errorBorder: border(colors.incorrect),
        focusedErrorBorder: border(colors.incorrect, AppStroke.focusRing),
        disabledBorder: border(colors.line),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colors.background,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: cardRadius,
          side: BorderSide(color: colors.line),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surface,
        selectedColor: colors.brandWash,
        secondarySelectedColor: colors.brandWash,
        labelStyle: text.labelMedium?.copyWith(color: colors.inkSecondary),
        secondaryLabelStyle: text.labelMedium?.copyWith(color: colors.brand),
        side: BorderSide(color: colors.line),
        shape: const StadiumBorder(),
        elevation: 0,
        pressElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.raised,
        surfaceTintColor: Colors.transparent,
        elevation: overlayElevation,
        shadowColor: colors.shadow,
        barrierColor: colors.scrim,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(overlayRadius),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.raised,
        surfaceTintColor: Colors.transparent,
        elevation: overlayElevation,
        modalElevation: overlayElevation,
        shadowColor: colors.shadow,
        modalBarrierColor: colors.scrim,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: overlayRadius),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: controlRadius),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colors.raised,
        indicatorShape: const RoundedRectangleBorder(borderRadius: cardRadius),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? colors.ink
                : colors.inkSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colors.brand
                : colors.inkSecondary,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.raised,
        indicatorShape: const RoundedRectangleBorder(borderRadius: cardRadius),
        selectedIconTheme: IconThemeData(color: colors.brand),
        unselectedIconTheme: IconThemeData(color: colors.inkSecondary),
        selectedLabelTextStyle: text.labelMedium?.copyWith(color: colors.ink),
        unselectedLabelTextStyle: text.labelMedium?.copyWith(
          color: colors.inkSecondary,
        ),
        elevation: 0,
        useIndicator: true,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.brand,
        linearTrackColor: colors.line,
        circularTrackColor: colors.line,
        linearMinHeight: AppSize.progressThickness,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    );
  }
}
