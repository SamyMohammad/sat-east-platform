import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/shared/widgets/app_dialog.dart';
import 'package:sat_east_client/shared/widgets/app_overlays.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';
import 'package:sat_east_client/shared/widgets/painters/dashed_border.dart';

/// Confirms a one-time submit (homework, quiz). Lists unanswered questions as
/// chips that close the dialog and jump back to them.
Future<void> showSubmitConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  required int total,
  required Set<int> answered,
  required VoidCallback? onSubmit,
  required ValueChanged<int>? onJumpTo,
}) {
  final unanswered = [
    for (var i = 0; i < total; i++)
      if (!answered.contains(i)) i,
  ];
  return showAppDialog<void>(
    context: context,
    builder: (dialogContext) => AppDialog(
      title: title,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpace.s3,
        children: [
          Text(body),
          if (unanswered.isNotEmpty)
            _UnansweredList(
              indices: unanswered,
              onPick: (i) {
                Navigator.of(dialogContext).pop();
                onJumpTo?.call(i);
              },
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Keep working'),
        ),
        LoadingButton(
          label: confirmLabel,
          onPressed: () {
            Navigator.of(dialogContext).pop();
            onSubmit?.call();
          },
        ),
      ],
    ),
  );
}

class _UnansweredList extends StatelessWidget {
  const _UnansweredList({required this.indices, required this.onPick});

  final List<int> indices;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final n = indices.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpace.s2,
      children: [
        Row(
          spacing: AppSpace.s2,
          children: [
            Icon(
              AppIcons.unanswered,
              size: AppSize.iconSmall,
              color: scheme.onSurface,
            ),
            Flexible(
              child: Text(
                n == 1 ? '1 question unanswered' : '$n questions unanswered',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        Wrap(
          spacing: AppSpace.s2,
          runSpacing: AppSpace.s2,
          children: [
            for (final i in indices)
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: AppSize.submitChipMinWidth,
                  minHeight: AppSize.touchTarget,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onPick(i),
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    child: CustomPaint(
                      foregroundPainter: DashedBorderPainter(
                        color: scheme.onSurfaceVariant,
                        radius: AppRadius.control,
                        strokeWidth: AppStroke.badge,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.s3,
                          vertical: AppSpace.s2,
                        ),
                        child: Center(
                          widthFactor: 1,
                          heightFactor: 1,
                          child: Text('Q${i + 1}'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const Text('Select one to go back to it.'),
      ],
    );
  }
}
