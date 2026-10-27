import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_motion.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/core/theme/app_type.dart';

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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => _build(context, constraints.maxWidth),
  );

  Widget _build(BuildContext context, double width) {
    if (modeLabel == 'Practice') return _practice(context, width);
    final layout = AppLayout.forWidth(width);
    final wide = layout != AppLayout.compact;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final titleStyle = wide
        ? theme.textTheme.titleLarge
        : theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);

    final back = IconButton(
      onPressed: onBack,
      tooltip: 'Back to topic',
      icon: const Icon(AppIcons.back),
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
      content = ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppSize.shellExpandedHeader,
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: AppSpace.s3,
            end: AppSpace.s8,
          ),
          child: Row(
            children: [
              back,
              const SizedBox(width: AppSpace.s1),
              Expanded(child: titles),
              const SizedBox(width: AppSpace.s6),
              SizedBox(width: AppSize.headerProgress, child: progress),
              if (trailing != null) ...[
                const SizedBox(width: AppSpace.s6),
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
          ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSize.shellCompactHeader,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s1),
              child: Row(
                children: [
                  back,
                  const SizedBox(width: AppSpace.s1),
                  Expanded(child: titles),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s4,
              0,
              AppSpace.s4,
              AppSpace.s3,
            ),
            child: _ProgressBlock(
              label: progressLabel,
              done: done,
              total: total,
              current: current,
              trailing: trailing,
            ),
          ),
        ],
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant,
            // Explicit: keeps the 1 px rule if the default changes.
            // ignore: avoid_redundant_argument_values
            width: AppStroke.thin,
          ),
        ),
      ),
      child: SafeArea(bottom: false, child: content),
    );
  }

  Widget _practice(BuildContext context, double width) {
    final compact = AppLayout.forWidth(width) == AppLayout.compact;
    final colors = context.appColors;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: '$title. $modeLabel. $progressLabel',
      child: SafeArea(
        bottom: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.line)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: compact
                      ? AppSize.shellCompactHeader
                      : AppSize.shellExpandedHeader,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? AppSpace.s1 : AppSpace.s6,
                  ),
                  child: Row(
                    spacing: AppSpace.s3,
                    children: [
                      IconButton(
                        onPressed: onBack,
                        tooltip: 'Back to topic',
                        icon: const Icon(AppIcons.close),
                      ),
                      if (!compact)
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              Text(
                                modeLabel,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: colors.inkSecondary),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: AppSize.headerProgress,
                          ),
                          child: _Segments(
                            done: done,
                            total: total,
                            current: current,
                          ),
                        ),
                      ),
                      Text(
                        '$done / $total',
                        style: AppType.count.copyWith(
                          color: colors.inkSecondary,
                        ),
                      ),
                      ?trailing,
                    ],
                  ),
                ),
              ),
              // Same column and gutters as the question body below, so the
              // line starts where the stem and choices start.
              Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? AppSpace.s5 : AppSpace.s6,
                  0,
                  compact ? AppSpace.s5 : AppSpace.s6,
                  AppSpace.s2,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppSize.questionColumn,
                    ),
                    child: ExcludeSemantics(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          progressLabel,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colors.inkSecondary),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressBlock extends StatelessWidget {
  const _ProgressBlock({
    required this.label,
    required this.done,
    required this.total,
    required this.current,
    this.trailing,
  });

  final Widget? trailing;
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
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpace.s2,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: AppSpace.s2),
        _Segments(done: done, total: total, current: current),
      ],
    );
  }
}

class _Segments extends StatelessWidget {
  const _Segments({required this.done, required this.total, this.current});
  final int done;
  final int total;
  final int? current;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: AppSize.progressSegmentGap),
          Expanded(
            child: AnimatedContainer(
              duration: AppMotion.resolve(context, AppMotion.state),
              curve: AppMotion.standard,
              key: ValueKey('progress-segment-$i'),
              height: AppSize.progressThickness,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                color: i < done
                    ? scheme.primary
                    : i == current
                    ? scheme.primaryContainer
                    : scheme.outlineVariant,
                border: i >= done && i == current
                    ? Border.all(
                        color: scheme.primary,
                        // Explicit: keeps the 1 px border.
                        // ignore: avoid_redundant_argument_values
                        width: AppStroke.thin,
                      )
                    : null,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
