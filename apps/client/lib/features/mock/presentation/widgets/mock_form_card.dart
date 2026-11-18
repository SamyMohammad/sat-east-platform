import 'package:flutter/material.dart';
import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/mock/domain/entities/mock_entities.dart';
import 'package:sat_east_client/features/mock/presentation/mock_copy.dart';
import 'package:sat_east_client/shared/widgets/app_chip.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

/// One mock form on the hub. [onAction] is null when the form has no action
/// (locked, finished, or another run must be resumed first).
class MockFormCard extends StatelessWidget {
  const MockFormCard({
    required this.form,
    required this.passedTopics,
    super.key,
    this.onAction,
    this.busy = false,
  });

  final MockHubForm form;
  final int passedTopics;
  final VoidCallback? onAction;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, icon) = switch (form.state) {
      MockFormState.locked => (MockCopy.locked, AppIcons.locked),
      MockFormState.available => (MockCopy.available, AppIcons.mockExams),
      MockFormState.inProgress => (MockCopy.inProgress, AppIcons.time),
      MockFormState.finished => (MockCopy.finished, AppIcons.completed),
    };
    final actionLabel = form.state == MockFormState.inProgress
        ? MockCopy.resume
        : MockCopy.start;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpace.s3,
          children: [
            Row(
              spacing: AppSpace.s3,
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      MockCopy.formTitle(form.k),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                AppChip(label: label, icon: icon),
              ],
            ),
            if (form.state == MockFormState.locked)
              Text(
                MockCopy.unlockHint(form.need, passedTopics),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: context.appColors.inkSecondary,
                ),
              ),
            if (onAction != null)
              LoadingButton(
                label: actionLabel,
                icon: AppIcons.forward,
                isLoading: busy,
                onPressed: onAction,
              ),
          ],
        ),
      ),
    );
  }
}
