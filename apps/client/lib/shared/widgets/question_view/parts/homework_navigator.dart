import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/question_navigator.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/submit_dialog.dart';

/// Right-hand navigator at `medium` and `expanded` widths.
class HomeworkNavigatorPanel extends StatelessWidget {
  const HomeworkNavigatorPanel({
    required this.title,
    required this.total,
    required this.index,
    required this.answered,
    required this.marked,
    required this.onJumpTo,
    required this.onSubmit,
    super.key,
  });

  final String title;
  final int total;
  final int index;
  final Set<int> answered;
  final Set<int> marked;
  final ValueChanged<int>? onJumpTo;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unanswered = total - answered.length;
    return SizedBox(
      key: const ValueKey('homework-navigator-panel'),
      width: AppSize.navigatorPanel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: BorderDirectional(
            start: BorderSide(color: scheme.outlineVariant),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: AppSpace.s3,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const NavigatorLegend(),
                      QuestionNavigatorGrid(
                        total: total,
                        index: index,
                        answered: answered,
                        marked: marked,
                        columns: 4,
                        onJumpTo: onJumpTo,
                      ),
                    ],
                  ),
                ),
              ),
              Divider(color: scheme.outlineVariant, height: AppSpace.s5),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpace.s3,
                children: [
                  Text(
                    '${answered.length} of $total answered · $unanswered '
                    'unanswered. You can submit once.',
                    style: theme.textTheme.bodySmall,
                  ),
                  LoadingButton(
                    label: 'Submit homework',
                    expanded: true,
                    onPressed: onSubmit == null
                        ? null
                        : () => _confirmHomeworkSubmit(
                            context,
                            total: total,
                            answered: answered,
                            onSubmit: onSubmit,
                            onJumpTo: onJumpTo,
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Homework copy for the shared submit confirmation (kept byte-identical).
Future<void> _confirmHomeworkSubmit(
  BuildContext context, {
  required int total,
  required Set<int> answered,
  required VoidCallback? onSubmit,
  required ValueChanged<int>? onJumpTo,
}) => showSubmitConfirmDialog(
  context,
  title: 'Submit homework?',
  body: 'You can submit once. After that your answers are locked and marked.',
  confirmLabel: 'Submit homework',
  total: total,
  answered: answered,
  onSubmit: onSubmit,
  onJumpTo: onJumpTo,
);

/// Phone navigator: a bottom sheet with a 6-column grid. Tapping a cell
/// closes the sheet, then jumps; Submit closes it and opens the dialog.
Future<void> showHomeworkNavigatorSheet(
  BuildContext context, {
  required String title,
  required int total,
  required int index,
  required Set<int> answered,
  required Set<int> marked,
  required ValueChanged<int>? onJumpTo,
  required VoidCallback? onSubmit,
}) => showNavigatorSheet(
  context,
  title: title,
  total: total,
  index: index,
  answered: answered,
  marked: marked,
  onJumpTo: onJumpTo,
  submitLabel: 'Submit homework',
  onSubmitPressed: onSubmit == null
      ? null
      : () => _confirmHomeworkSubmit(
          context,
          total: total,
          answered: answered,
          onSubmit: onSubmit,
          onJumpTo: onJumpTo,
        ),
);
