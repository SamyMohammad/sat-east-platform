import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/booklet_tokens.dart';

/// Pinned 72 px action bar. Phone: leading, centred middle, primary. Wide:
/// 1fr / auto / 1fr grid with the optional [helper] beside the primary.
class QuestionFooter extends StatelessWidget {
  const QuestionFooter({
    required this.leading,
    required this.middle,
    required this.primary,
    super.key,
    this.helper,
  });

  final Widget? leading;
  final Widget middle;
  final Widget primary;
  final String? helper;

  static const double _maxTextScale = 1.3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final compact =
        BookletLayout.forWidth(MediaQuery.sizeOf(context).width) ==
        BookletLayout.compact;

    final Widget content;
    if (compact) {
      content = Row(
        spacing: BookletSpace.s2,
        children: [
          ?leading,
          Expanded(child: Center(child: middle)),
          primary,
        ],
      );
    } else {
      content = Row(
        children: [
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: leading,
            ),
          ),
          middle,
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: BookletSpace.s4,
                children: [
                  if (helper != null)
                    Flexible(
                      child: Text(
                        helper!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  primary,
                ],
              ),
            ),
          ),
        ],
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: BookletSize.footerHeight,
          // Fixed-height bar: cap text scale so the buttons never outgrow it.
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: _maxTextScale,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? BookletSpace.s4 : BookletSpace.s8,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
