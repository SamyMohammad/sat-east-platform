import 'package:flutter/material.dart';

import 'package:sat_east_client/core/text/text_direction.dart';
import 'package:sat_east_client/core/theme/booklet_colors.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';

enum BookletButtonVariant { primary, secondary, tertiary, destructive }

class LoadingButton extends StatelessWidget {
  const LoadingButton({
    required this.label,
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.errorText,
    this.variant = BookletButtonVariant.primary,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final String? errorText;
  final BookletButtonVariant variant;

  /// Fills the available width instead of hugging the label.
  final bool expanded;

  bool get _filled =>
      variant == BookletButtonVariant.primary ||
      variant == BookletButtonVariant.destructive;

  @override
  Widget build(BuildContext context) {
    final style = _style(context);
    final content = _content(context);
    final callback = isLoading ? null : onPressed;
    final button = switch (variant) {
      BookletButtonVariant.primary || BookletButtonVariant.destructive =>
        FilledButton(onPressed: callback, style: style, child: content),
      BookletButtonVariant.secondary => OutlinedButton(
        onPressed: callback,
        style: style,
        child: content,
      ),
      BookletButtonVariant.tertiary => TextButton(
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
      spacing: BookletSpace.s1,
      children: [
        Semantics(value: isLoading ? 'Loading' : null, child: button),
        if (errorText case final error?) _error(context, error),
      ],
    );
  }

  Color _foreground(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (variant) {
      BookletButtonVariant.primary => scheme.onPrimary,
      BookletButtonVariant.destructive => scheme.surface,
      BookletButtonVariant.secondary ||
      BookletButtonVariant.tertiary => scheme.primary,
    };
  }

  ButtonStyle _style(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final destructive = variant == BookletButtonVariant.destructive;
    final background = destructive ? scheme.onSurface : scheme.primary;
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size(BookletSize.touchTarget, BookletSize.touchTarget),
      ),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: _filled || variant == BookletButtonVariant.secondary
              ? BookletSpace.s4 + BookletSpace.s1
              : BookletSpace.s3,
          vertical: BookletSpace.s2,
        ),
      ),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(BookletRadius.sm)),
        ),
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) && !isLoading
            ? context.booklet.inkDisabled
            : _foreground(context),
      ),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (!_filled) return null;
        if (states.contains(WidgetState.disabled) && !isLoading) {
          return scheme.outlineVariant;
        }
        if (states.contains(WidgetState.hovered) && !destructive) {
          return context.booklet.primaryHover;
        }
        return background;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        if (variant != BookletButtonVariant.secondary) return BorderSide.none;
        return BorderSide(
          color: states.contains(WidgetState.disabled) && !isLoading
              ? scheme.outlineVariant
              : scheme.primary,
        );
      }),
      animationDuration: BookletMotion.resolve(context, BookletMotion.base),
    );
  }

  Widget _content(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: BookletSpace.s2,
    children: [
      if (isLoading)
        ExcludeSemantics(
          child: TickerMode(
            enabled: !MediaQuery.disableAnimationsOf(context),
            child: SizedBox.square(
              dimension: BookletSize.spinner,
              child: CircularProgressIndicator(
                strokeWidth: BookletStroke.strong,
                color: _foreground(context),
              ),
            ),
          ),
        )
      else if (icon != null)
        Icon(icon, size: BookletSize.iconSmall),
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
      spacing: BookletSpace.s1,
      children: [
        Icon(
          Icons.error_outline,
          size: BookletSize.iconStatus,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        Flexible(
          child: Text(
            error,
            textDirection: detectTextDirection(error),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    ),
  );
}
