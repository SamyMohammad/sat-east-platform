import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';

/// Quiz question header: number badge and a "Mark for review" toggle.
class QuizQuestionHeader extends StatelessWidget {
  const QuizQuestionHeader({
    required this.number,
    required this.marked,
    super.key,
    this.onMark,
  });

  final int number;
  final bool marked;

  /// Null disables the toggle (e.g. time is up).
  final VoidCallback? onMark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.s3),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.raised,
                border: Border.all(color: colors.lineStrong),
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: SizedBox.square(
                dimension: AppSize.examQuestionBadge,
                child: Center(
                  child: Text(
                    '$number',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpace.s2),
            Flexible(
              child: Semantics(
                toggled: marked,
                button: true,
                child: OutlinedButton.icon(
                  onPressed: onMark,
                  icon: Icon(
                    marked ? AppIcons.bookmarked : AppIcons.bookmark,
                    size: AppSize.iconSmall,
                  ),
                  label: Text(
                    marked ? 'Marked for review' : 'Mark for review',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: marked ? colors.ink : scheme.onSurface,
                    backgroundColor: marked ? colors.brandWash : null,
                    minimumSize: const Size(0, AppSize.examToggleHeight),
                    tapTargetSize: MaterialTapTargetSize.padded,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s2,
                      vertical:
                          (AppSize.examToggleHeight - AppSize.iconSmall) / 2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
