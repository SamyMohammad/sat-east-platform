import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_tokens.dart';

/// Pinned 72 px action bar. Phone: leading, centred middle, primary. Wide:
/// 1fr / auto / 1fr grid with the optional [helper] beside the primary.
class QuestionFooter extends StatelessWidget {
  const QuestionFooter({
    required this.leading,
    required this.middle,
    required this.primary,
    super.key,
    this.helper,
    this.phoneComposition = false,
  });

  final Widget? leading;
  final Widget middle;
  final Widget primary;
  final String? helper;

  /// Lays out like the phone footer (flexible middle, stacks at large text
  /// scales) even on wide screens. For footers whose wide grid would not fit.
  final bool phoneComposition;

  /// Above this text scale the phone footer stacks instead of squeezing.
  static const double _stackScale = 1.3;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            AppLayout.forWidth(constraints.maxWidth) == AppLayout.compact;
        final scheme = Theme.of(context).colorScheme;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(top: BorderSide(color: scheme.outlineVariant)),
          ),
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSize.footerHeight,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? AppSpace.s3 : AppSpace.s8,
                  vertical: compact ? AppSpace.s2 : 0,
                ),
                child: compact || phoneComposition
                    ? _compact(context)
                    : _wide(context),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _compact(BuildContext context) {
    final stack = MediaQuery.textScalerOf(context).scale(1) > _stackScale;
    if (stack) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpace.s2,
        children: [
          middle,
          Row(
            mainAxisAlignment: leading == null
                ? MainAxisAlignment.end
                : MainAxisAlignment.spaceBetween,
            children: [
              ?leading,
              Flexible(child: primary),
            ],
          ),
        ],
      );
    }
    return Row(
      spacing: AppSpace.s1,
      children: [
        ?leading,
        Expanded(child: Center(child: middle)),
        primary,
      ],
    );
  }

  Widget _wide(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
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
              spacing: AppSpace.s4,
              children: [
                if (helper != null)
                  Flexible(
                    child: Text(
                      helper!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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
}
