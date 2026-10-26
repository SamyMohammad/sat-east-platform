import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/booklet_colors.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';

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
    final colors = context.booklet;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: BookletSpace.s3),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.onSurface,
                borderRadius: BorderRadius.circular(BookletRadius.xs),
              ),
              child: SizedBox.square(
                dimension: BookletSize.examQuestionBadge,
                child: Center(
                  child: Text(
                    '$number',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.surface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: BookletSpace.s2),
            Flexible(
              child: Semantics(
                toggled: marked,
                button: true,
                child: OutlinedButton.icon(
                  onPressed: onMark,
                  icon: Icon(
                    marked ? AppIcons.bookmarked : AppIcons.bookmark,
                    size: BookletSize.iconSmall,
                  ),
                  label: Text(
                    marked ? 'Marked for review' : 'Mark for review',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: marked
                        ? colors.onHighlighter
                        : scheme.onSurface,
                    backgroundColor: marked ? colors.highlighter : null,
                    minimumSize: const Size(0, BookletSize.examToggleHeight),
                    tapTargetSize: MaterialTapTargetSize.padded,
                    padding: const EdgeInsets.symmetric(
                      horizontal: BookletSpace.s2,
                      vertical:
                          (BookletSize.examToggleHeight -
                              BookletSize.iconSmall) /
                          2,
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
