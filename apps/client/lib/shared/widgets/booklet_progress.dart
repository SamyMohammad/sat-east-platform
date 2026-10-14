import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/booklet_tokens.dart';

class BookletProgress extends StatelessWidget {
  const BookletProgress({
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
              spacing: BookletSpace.s2,
              runSpacing: BookletSpace.s1,
              children: [
                Text(label, style: theme.textTheme.labelSmall),
                if (valueLabel != null)
                  Text(
                    valueLabel!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: BookletSpace.s2),
            TickerMode(
              enabled: !MediaQuery.disableAnimationsOf(context),
              child: LinearProgressIndicator(
                value: renderedValue,
                minHeight: BookletSize.progressThickness,
                backgroundColor: theme.colorScheme.outlineVariant,
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.zero,
                trackGap: 0,
                stopIndicatorRadius: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
