import 'package:flutter/material.dart';

import 'package:sat_east_client/core/math_render/math_text.dart';
import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';

/// Widest share of the heading row the title may take before it ellipsizes.
const double _maxTitleShare = 0.6;

/// Frame-tinted block with a titled rule line and a `MathText` body.
/// Shared by `HintPanel` and `WorkedExample`.
class FramedPanel extends StatelessWidget {
  const FramedPanel({
    required this.title,
    required this.md,
    required this.padding,
    required this.titleColor,
    super.key,
    this.icon,
  });

  final IconData? icon;
  final String title;
  final String md;
  final double padding;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final base = theme.textTheme.labelSmall;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: icon == null
            ? context.appColors.background
            : context.appColors.warm,
        border: Border.all(
          color: icon == null
              ? context.appColors.line
              : context.appColors.warmLine,
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The title takes its natural width (capped at 60% of the row so a
            // long label ellipsizes); the rule fills whatever is left.
            LayoutBuilder(
              builder: (context, constraints) => Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: AppSize.iconStatus, color: titleColor),
                    const SizedBox(width: AppSpace.s2),
                  ],
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * _maxTitleShare,
                    ),
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: base?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w700,
                        letterSpacing: AppTracking.caps,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s2),
                  Expanded(
                    child: SizedBox(
                      height: AppStroke.thin,
                      child: ColoredBox(color: scheme.outlineVariant),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.s3),
            MathText(md, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
