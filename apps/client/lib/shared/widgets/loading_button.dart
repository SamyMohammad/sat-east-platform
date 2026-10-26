import 'package:flutter/material.dart';

import 'package:sat_east_client/core/text/text_direction.dart';
import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_motion.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';

part 'loading_button_surface.dart';

enum AppButtonVariant { primary, secondary, tertiary, destructive }

class LoadingButton extends StatelessWidget {
  const LoadingButton({
    required this.label,
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.errorText,
    this.variant = AppButtonVariant.primary,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final String? errorText;
  final AppButtonVariant variant;

  /// Fills the available width instead of hugging the label.
  final bool expanded;

  bool get _filled =>
      variant == AppButtonVariant.primary ||
      variant == AppButtonVariant.destructive;

  @override
  Widget build(BuildContext context) {
    final style = _style(context);
    final content = _content(context);
    final callback = isLoading ? null : onPressed;
    Widget button(WidgetStatesController states) => switch (variant) {
      AppButtonVariant.primary || AppButtonVariant.destructive => FilledButton(
        statesController: states,
        onPressed: callback,
        style: style,
        child: content,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        statesController: states,
        onPressed: callback,
        style: style,
        child: content,
      ),
      AppButtonVariant.tertiary => TextButton(
        statesController: states,
        onPressed: callback,
        style: style,
        child: content,
      ),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: expanded
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.start,
      spacing: AppSpace.s1,
      children: [
        Semantics(
          value: isLoading ? 'Loading' : null,
          child: _ButtonSurface(
            enabled: callback != null,
            primary: variant == AppButtonVariant.primary,
            builder: button,
          ),
        ),
        if (errorText case final error?) _error(context, error),
      ],
    );
  }

  Color _foreground(BuildContext context) {
    final scheme = context.appColors;
    return switch (variant) {
      AppButtonVariant.primary => scheme.onBrand,
      AppButtonVariant.destructive => scheme.surface,
      AppButtonVariant.secondary || AppButtonVariant.tertiary => scheme.brand,
    };
  }

  ButtonStyle _style(BuildContext context) {
    final scheme = context.appColors;
    final destructive = variant == AppButtonVariant.destructive;
    final background = destructive ? scheme.ink : scheme.brand;
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size(AppSize.touchTarget, AppSize.touchTarget),
      ),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: _filled || variant == AppButtonVariant.secondary
              ? AppSpace.s4 + AppSpace.s1
              : AppSpace.s3,
          vertical: AppSpace.s2,
        ),
      ),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.control)),
        ),
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) && !isLoading
            ? context.appColors.inkTertiary
            : _foreground(context),
      ),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (!_filled) return null;
        if (states.contains(WidgetState.disabled) && !isLoading) {
          return scheme.line;
        }
        if (states.contains(WidgetState.hovered) && !destructive) {
          return context.appColors.brand;
        }
        return background;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        if (variant != AppButtonVariant.secondary) return BorderSide.none;
        return BorderSide(
          color: states.contains(WidgetState.disabled) && !isLoading
              ? scheme.line
              : scheme.brand,
        );
      }),
      elevation: const WidgetStatePropertyAll(0),
      animationDuration: AppMotion.resolve(context, AppMotion.state),
    );
  }

  Widget _content(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: AppSpace.s2,
    children: [
      if (isLoading)
        ExcludeSemantics(
          child: TickerMode(
            enabled: !MediaQuery.disableAnimationsOf(context),
            child: SizedBox.square(
              dimension: AppSize.spinner,
              child: CircularProgressIndicator(
                strokeWidth: AppStroke.strong,
                color: _foreground(context),
              ),
            ),
          ),
        )
      else if (icon != null)
        Icon(icon, size: AppSize.iconSmall),
      Flexible(
        child: Text(
          label,
          textAlign: TextAlign.center,
          textDirection: detectTextDirection(label),
        ),
      ),
    ],
  );

  Widget _error(BuildContext context, String error) => Semantics(
    liveRegion: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpace.s1,
      children: [
        Icon(
          AppIcons.error,
          size: AppSize.iconStatus,
          color: context.appColors.ink,
        ),
        Flexible(
          child: Text(
            error,
            textDirection: detectTextDirection(error),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: context.appColors.ink,
            ),
          ),
        ),
      ],
    ),
  );
}
