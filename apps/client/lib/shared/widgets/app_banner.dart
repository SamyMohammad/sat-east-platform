import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

enum AppBannerKind { info, warning, offline, error, success }

class AppBanner extends StatelessWidget {
  const AppBanner({
    required this.message,
    super.key,
    this.kind = AppBannerKind.info,
    this.actionLabel,
    this.onAction,
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'Provide both actionLabel and onAction, or neither.',
       );

  final String message;
  final AppBannerKind kind;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.appColors;
    final (color, background, line, icon) = switch (kind) {
      AppBannerKind.success => (
        scheme.correct,
        scheme.correctWash,
        scheme.correctLine,
        AppIcons.correct,
      ),
      AppBannerKind.info => (
        context.appColors.brand,
        context.appColors.brandWash,
        scheme.brandLine,
        AppIcons.info,
      ),
      AppBannerKind.warning => (
        context.appColors.warning,
        context.appColors.warningWash,
        scheme.warmLine,
        AppIcons.time,
      ),
      AppBannerKind.offline => (
        scheme.ink,
        scheme.surface,
        scheme.line,
        AppIcons.unsynced,
      ),
      AppBannerKind.error => (
        scheme.incorrect,
        scheme.incorrectWash,
        scheme.incorrectLine,
        AppIcons.error,
      ),
    };
    final text = Semantics(
      liveRegion: true,
      child: Text(
        message,
        textDirection: TextDirection.ltr,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w400,
          color: scheme.ink,
        ),
      ),
    );
    final action = actionLabel == null
        ? null
        : LoadingButton(
            label: actionLabel!,
            onPressed: onAction,
            variant: AppButtonVariant.tertiary,
          );
    return Container(
      constraints: const BoxConstraints(minHeight: AppSize.largeControl),
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpace.s4,
        AppSpace.s2,
        AppSpace.s2,
        AppSpace.s2,
      ),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: line),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              AppLayout.forWidth(constraints.maxWidth) == AppLayout.compact ||
              MediaQuery.textScalerOf(context).scale(AppSize.iconSmall) >
                  AppSize.iconSmall;
          return Row(
            crossAxisAlignment: compact
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            spacing: AppSpace.s3,
            children: [
              Icon(icon, size: AppSize.iconSmall, color: color),
              Expanded(
                child: compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        spacing: AppSpace.s2,
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
