import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/booklet_tokens.dart';

/// Top bar of the question screen: back, title, mode label, segmented
/// progress and an optional trailing slot. Phone stacks the progress block
/// under the row; wide puts it on the right.
class QuestionHeader extends StatelessWidget {
  const QuestionHeader({
    required this.title,
    required this.modeLabel,
    required this.progressLabel,
    required this.done,
    required this.total,
    super.key,
    this.current,
    this.onBack,
    this.trailing,
  });

  final String title;
  final String modeLabel;
  final String progressLabel;
  final int done;
  final int total;
  final int? current;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final layout = BookletLayout.forWidth(MediaQuery.sizeOf(context).width);
    final wide = layout != BookletLayout.compact;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final titleStyle = wide
        ? theme.textTheme.titleLarge
        : theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);

    final back = IconButton(
      onPressed: onBack,
      tooltip: 'Back to topic',
      icon: const Icon(Icons.arrow_back_rounded),
    );
    final titles = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: titleStyle,
        ),
        Text(
          modeLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    final progress = _ProgressBlock(
      label: progressLabel,
      done: done,
      total: total,
      current: current,
    );

    final Widget content;
    if (wide) {
      content = SizedBox(
        height: BookletSize.shellExpandedHeader,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: BookletSpace.s3,
            end: BookletSpace.s8,
          ),
          child: Row(
            children: [
              back,
              const SizedBox(width: BookletSpace.s1),
              Expanded(child: titles),
              const SizedBox(width: BookletSpace.s6),
              SizedBox(width: BookletSize.headerProgress, child: progress),
              if (trailing != null) ...[
                const SizedBox(width: BookletSpace.s6),
                trailing!,
              ],
            ],
          ),
        ),
      );
    } else {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: BookletSize.shellCompactHeader,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: BookletSpace.s1),
              child: Row(
                children: [
                  back,
                  const SizedBox(width: BookletSpace.s1),
                  Expanded(child: titles),
                  ?trailing,
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BookletSpace.s4,
              0,
              BookletSpace.s4,
              BookletSpace.s3,
            ),
            child: progress,
          ),
        ],
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant,
          ),
        ),
      ),
      child: SafeArea(bottom: false, child: content),
    );
  }
}

class _ProgressBlock extends StatelessWidget {
  const _ProgressBlock({
    required this.label,
    required this.done,
    required this.total,
    required this.current,
  });

  final String label;
  final int done;
  final int total;
  final int? current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: BookletSpace.s2 - BookletSpace.s1 / 2),
        Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: BookletSize.progressSegmentGap),
              Expanded(
                child: Container(
                  key: ValueKey('progress-segment-$i'),
                  height: BookletSize.progressThickness,
                  decoration: BoxDecoration(
                    color: i < done
                        ? scheme.primary
                        : i == current
                        ? scheme.primaryContainer
                        : scheme.outlineVariant,
                    border: i >= done && i == current
                        ? Border.all(
                            color: scheme.primary,
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
