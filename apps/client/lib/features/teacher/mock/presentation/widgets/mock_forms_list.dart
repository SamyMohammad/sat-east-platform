import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/teacher/mock/domain/entities/mock_entities.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/mock_copy.dart';
import 'package:sat_east_client/shared/widgets/app_chip.dart';
import 'package:sat_east_client/shared/widgets/empty_state.dart';

/// Forms sorted by set then form; each row opens the form detail page.
class MockFormsList extends StatelessWidget {
  const MockFormsList({required this.forms, super.key});
  final List<MockFormSummary> forms;

  @override
  Widget build(BuildContext context) {
    if (forms.isEmpty) {
      return const EmptyState(
        title: mockNoFormsTitle,
        message: mockNoFormsMessage,
        icon: AppIcons.mockExams,
      );
    }
    final sorted = [...forms]
      ..sort((a, b) {
        final bySet = a.setNo.compareTo(b.setNo);
        return bySet != 0 ? bySet : a.formNo.compareTo(b.formNo);
      });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpace.s2,
      children: [for (final form in sorted) _FormRow(form: form)],
    );
  }
}

class _FormRow extends StatelessWidget {
  const _FormRow({required this.form});
  final MockFormSummary form;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final publishedAt = form.publishedAt;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        side: BorderSide(color: colors.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.control),
        onTap: () =>
            context.go(AppRoutes.teacherMockForm(form.setNo, form.formNo)),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s4,
            vertical: AppSpace.s3,
          ),
          child: Row(
            spacing: AppSpace.s3,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mockFormTitle(form.setNo, form.formNo),
                      style: theme.textTheme.titleSmall,
                    ),
                    if (publishedAt != null)
                      Text(
                        mockPublishedLine(publishedAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.inkSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              AppChip(label: mockStatusLabel(form.status)),
              const Icon(AppIcons.next),
            ],
          ),
        ),
      ),
    );
  }
}
