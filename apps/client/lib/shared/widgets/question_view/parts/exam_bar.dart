import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/exam_clock.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/exam_clock_pulse.dart';

/// Dark quiz bar: title, countdown clock and a budget-elapsed track.
/// Phone ([compact]) shows the short title; wide adds Hide/Show for the timer.
class ExamBar extends StatelessWidget {
  const ExamBar({
    required this.title,
    required this.shortTitle,
    required this.subtitle,
    required this.remaining,
    required this.timeBudget,
    required this.warning,
    required this.timerHidden,
    required this.compact,
    super.key,
    this.onToggleTimer,
  });

  final String title;
  final String shortTitle;
  final String subtitle;
  final Duration remaining;
  final Duration timeBudget;
  final bool warning;
  final bool timerHidden;
  final bool compact;
  final VoidCallback? onToggleTimer;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.appColors.examBar,
      child: SafeArea(
        bottom: false,
        child: compact ? _phone(context) : _wide(context),
      ),
    );
  }

  Widget _clock(BuildContext context, TextStyle? base) {
    final colors = context.appColors;
    final color = warning ? colors.examBarWarning : colors.onExamBar;
    final text = Semantics(
      label: 'Time left ${formatClock(remaining)}',
      child: ExcludeSemantics(
        child: Text(
          formatClock(remaining),
          maxLines: 1,
          style: base?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
    if (!warning) return ExamClockPulse(warning: warning, child: text);
    return ExamClockPulse(
      warning: warning,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.time, size: AppSize.iconSmall, color: color),
          const SizedBox(width: AppSpace.s1),
          text,
        ],
      ),
    );
  }

  Widget _track(BuildContext context, double width, double thickness) {
    final colors = context.appColors;
    return SizedBox(
      key: const ValueKey('exam-budget-bar'),
      width: width,
      height: thickness,
      child: ColoredBox(
        color: colors.examBarRule,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: FractionallySizedBox(
            widthFactor: budgetFraction(remaining, timeBudget),
            heightFactor: 1,
            child: ColoredBox(
              color: warning ? colors.examBarWarning : colors.examBarPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _phone(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = context.appColors;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSize.examBarCompact),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s4,
          vertical: AppSpace.s1,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    shortTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(
                      color: colors.onExamBar,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      color: colors.onExamBarVariant,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _clock(context, textTheme.titleMedium),
                const SizedBox(height: AppSpace.s1),
                _track(
                  context,
                  AppSize.examBudgetCompact,
                  AppSize.examBudgetThinThickness,
                ),
              ],
            ),
            const Expanded(child: SizedBox.shrink()),
          ],
        ),
      ),
    );
  }

  Widget _wide(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = context.appColors;
    final showToggle = onToggleTimer != null && !warning;
    final hidden = timerHidden && !warning;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSize.examBarWide),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: AppSpace.s6,
          end: AppSpace.s3,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium?.copyWith(
                  color: colors.onExamBar,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hidden) ...[
                      Icon(
                        AppIcons.timerHidden,
                        size: AppSize.iconSmall,
                        color: colors.onExamBarVariant,
                      ),
                      const SizedBox(width: AppSpace.s2),
                      Text(
                        'Timer hidden',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colors.onExamBarVariant,
                        ),
                      ),
                    ] else
                      _clock(context, textTheme.titleLarge),
                    if (showToggle) ...[
                      const SizedBox(width: AppSpace.s3),
                      _toggleButton(context, hidden: hidden),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpace.s1),
                _track(
                  context,
                  AppSize.examBudgetWide,
                  AppSize.progressThickness,
                ),
              ],
            ),
            const Expanded(child: SizedBox.shrink()),
          ],
        ),
      ),
    );
  }

  Widget _toggleButton(BuildContext context, {required bool hidden}) {
    final colors = context.appColors;
    return Semantics(
      label: hidden ? 'Show timer' : 'Hide timer',
      button: true,
      excludeSemantics: true,
      onTap: onToggleTimer,
      child: OutlinedButton(
        onPressed: onToggleTimer,
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.onExamBar,
          side: BorderSide(color: colors.examBarRule),
          minimumSize: const Size(0, AppSize.examTimerButtonHeight),
          tapTargetSize: MaterialTapTargetSize.padded,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3),
        ),
        child: Text(hidden ? 'Show' : 'Hide'),
      ),
    );
  }
}

/// Orange banner shown once the quiz clock reaches `warnAt`. Announced as a
/// live region.
class ExamWarningBanner extends StatelessWidget {
  const ExamWarningBanner({
    required this.warnAt,
    super.key,
    this.onReviewMarked,
  });

  final Duration warnAt;
  final VoidCallback? onReviewMarked;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final minutes = (warnAt.inMilliseconds / Duration.millisecondsPerMinute)
        .ceil();
    final lead = '$minutes ${minutes == 1 ? 'minute' : 'minutes'} left.';
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.warningWash,
          border: Border(bottom: BorderSide(color: colors.warning)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSize.warningBannerMinHeight,
          ),
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s4,
                vertical: AppSpace.s2,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpace.s2,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpace.s1),
                    child: Icon(
                      AppIcons.time,
                      size: AppSize.iconSmall,
                      color: colors.warning,
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: AppSpace.s2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text.rich(
                          TextSpan(
                            style: textTheme.bodyMedium?.copyWith(
                              color: colors.warning,
                            ),
                            children: [
                              TextSpan(
                                text: lead,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const TextSpan(
                                text:
                                    ' Answer the rest; a guess scores better '
                                    'than a blank.',
                              ),
                            ],
                          ),
                        ),
                        if (onReviewMarked != null)
                          TextButton(
                            onPressed: onReviewMarked,
                            style: TextButton.styleFrom(
                              foregroundColor: colors.warning,
                              minimumSize: const Size(
                                0,
                                AppSize.touchTarget,
                              ),
                            ),
                            child: const Text('Review marked'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
