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

  /// Title letter-spacing, in em.
  static const double _tracking = 0.08;

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
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: BookletSize.iconStatus, color: titleColor),
                  const SizedBox(width: BookletSpace.s2),
                ],
                Flexible(
                  child: Text(
                    title,
                    style: base?.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.w700,
                      letterSpacing: (base.fontSize ?? 12) * _tracking,
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
            const SizedBox(height: BookletSpace.s3),
            MathText(md, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
