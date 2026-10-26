import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_motion.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';

part 'app_progress_segments.dart';

class AppProgress extends StatelessWidget {
  const AppProgress({
    required this.label,
    super.key,
    this.value,
    this.valueLabel,
  });

  final String label;
  final double? value;
  final String? valueLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final renderedValue = value != null && value!.isFinite
        ? value!.clamp(0.0, 1.0)
        : null;
    return Semantics(
      label: label,
      value: valueLabel,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: AppSpace.s2,
              runSpacing: AppSpace.s1,
              children: [
                Text(label, style: theme.textTheme.labelSmall),
                if (valueLabel != null)
                  Text(
                    valueLabel!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: context.appColors.inkSecondary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.s2),
            ClipPath(
              clipper: const _ProgressSegments(),
              child: TickerMode(
                enabled: !AppMotion.reduced(context),
                child: renderedValue == null || AppMotion.reduced(context)
                    ? _bar(context, renderedValue)
                    : TweenAnimationBuilder<double>(
                        tween: Tween(begin: renderedValue, end: renderedValue),
                        duration: AppMotion.resolve(context, AppMotion.state),
                        curve: AppMotion.standard,
                        builder: (context, fill, _) => _bar(context, fill),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar(BuildContext context, double? fill) => LinearProgressIndicator(
    value: fill,
    minHeight: AppSize.progressThickness,
    backgroundColor: context.appColors.line,
    color: context.appColors.brand,
    borderRadius: BorderRadius.circular(AppRadius.pill),
    trackGap: 0,
    stopIndicatorRadius: 0,
  );
}
