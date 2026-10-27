import 'package:flutter/material.dart';

import 'package:sat_east_client/core/math_render/math_text.dart';
import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';

/// Framed block with a sentence-case title beside its icon and a `MathText`
/// body. Shared by `HintPanel` (warm) and `WorkedExample` (plain).
class FramedPanel extends StatelessWidget {
  const FramedPanel({
    required this.icon,
    required this.title,
    required this.md,
    required this.padding,
    required this.titleColor,
    super.key,
    this.warm = false,
  });

  final IconData icon;
  final String title;
  final String md;
  final double padding;
  final Color titleColor;
  final bool warm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: warm ? colors.warm : colors.background,
        border: Border.all(color: warm ? colors.warmLine : colors.line),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpace.s3,
          children: [
            Row(
              spacing: AppSpace.s2,
              children: [
                Icon(icon, size: AppSize.iconStatus, color: titleColor),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            MathText(md, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
