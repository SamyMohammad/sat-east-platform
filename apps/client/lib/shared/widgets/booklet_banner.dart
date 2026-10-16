import 'package:flutter/material.dart';

import 'package:sat_east_client/core/text/text_direction.dart';
import 'package:sat_east_client/core/theme/booklet_colors.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';

import 'package:sat_east_client/shared/widgets/loading_button.dart';

enum BookletBannerKind { info, warning, offline, error }

class BookletBanner extends StatelessWidget {
  const BookletBanner({
    required this.message,
    super.key,
    this.kind = BookletBannerKind.info,
    this.actionLabel,
    this.onAction,
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'Provide both actionLabel and onAction, or neither.',
       );

  final String message;
  final BookletBannerKind kind;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (color, background, icon) = switch (kind) {
      BookletBannerKind.info => (
        context.booklet.info,
        context.booklet.infoContainer,
        Icons.info_outline,
      ),
      BookletBannerKind.warning => (
        context.booklet.warning,
        context.booklet.warningContainer,
        Icons.schedule,
      ),
      BookletBannerKind.offline => (
        scheme.onSurface,
        scheme.surfaceContainer,
        Icons.cloud_off,
      ),
      BookletBannerKind.error => (
        scheme.error,
        scheme.errorContainer,
        Icons.error_outline,
      ),
    };
    final text = Semantics(
      liveRegion: true,
      child: Text(
        message,
        textDirection: detectTextDirection(message),
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w400,
          color: scheme.onSurface,
        ),
      ),
    );
    final action = actionLabel == null
        ? null
        : LoadingButton(
            label: actionLabel!,
            onPressed: onAction,
            variant: BookletButtonVariant.tertiary,
          );
    return Container(
      constraints: const BoxConstraints(minHeight: BookletSize.largeControl),
      padding: const EdgeInsetsDirectional.fromSTEB(
        BookletSpace.s4,
        BookletSpace.s2,
        BookletSpace.s2,
        BookletSpace.s2,
      ),
      decoration: BoxDecoration(
        color: background,
        border: Border(
          top: BorderSide(
            color: kind == BookletBannerKind.offline ? scheme.outline : color,
          ),
          bottom: BorderSide(
            color: scheme.outlineVariant,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              BookletLayout.forWidth(constraints.maxWidth) ==
                  BookletLayout.compact ||
              MediaQuery.textScalerOf(context).scale(BookletSize.iconSmall) >
                  BookletSize.iconSmall;
          return Row(
            crossAxisAlignment: compact
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            spacing: BookletSpace.s3,
            children: [
              Icon(icon, size: BookletSize.iconSmall, color: color),
              Expanded(
                child: compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        spacing: BookletSpace.s2,
                        children: [text, ?action],
                      )
                    : text,
              ),
              if (!compact && action != null)
                LimitedBox(
                  maxWidth: constraints.maxWidth / 3,
                  child: action,
                ),
            ],
          );
        },
      ),
    );
  }
}
