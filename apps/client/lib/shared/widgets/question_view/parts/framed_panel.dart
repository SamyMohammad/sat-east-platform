import 'package:flutter/material.dart';

import 'package:sat_east_client/core/math_render/math_text.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';

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
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(BookletRadius.xs),
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
                    Icon(icon, size: BookletSize.iconStatus, color: titleColor),
                    const SizedBox(width: BookletSpace.s2),
                  ],
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * 0.6,
                    ),
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: base?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w700,
                        letterSpacing: BookletTracking.caps,
                      ),
                    ),
                  ),
                  const SizedBox(width: BookletSpace.s2),
                  Expanded(
                    child: SizedBox(
                      height: BookletStroke.thin,
                      child: ColoredBox(color: scheme.outlineVariant),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: BookletSpace.s3),
            MathText(md, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
