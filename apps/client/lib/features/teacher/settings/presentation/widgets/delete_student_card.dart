import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/teacher/settings/presentation/cubit/delete_student_cubit.dart';
import 'package:sat_east_client/features/teacher/settings/presentation/cubit/delete_student_state.dart';
import 'package:sat_east_client/features/teacher/settings/presentation/teacher_settings_copy.dart';
import 'package:sat_east_client/shared/widgets/app_dialog.dart';

/// "Delete a student" section of the teacher settings page (P3.7).
class DeleteStudentCard extends StatefulWidget {
  const DeleteStudentCard({super.key});
  @override
  State<DeleteStudentCard> createState() => _DeleteStudentCardState();
}

class _DeleteStudentCardState extends State<DeleteStudentCard> {
  late final TextEditingController _email;
  @override
  void initState() {
    super.initState();
    _email = TextEditingController();
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final cubit = context.read<DeleteStudentCubit>();
    final email = _email.text.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDeleteDialog(email: email),
    );
    if (confirmed ?? false) await cubit.delete(email);
  }

  void _onState(BuildContext context, DeleteStudentState state) {
    final message = switch (state) {
      DeleteStudentDone() => 'Student deleted',
      DeleteStudentFailed(:final error) => deleteStudentError(error.code),
      _ => null,
    };
    if (state is DeleteStudentDone) _email.clear();
    if (message == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    context.read<DeleteStudentCubit>().reset();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return BlocListener<DeleteStudentCubit, DeleteStudentState>(
      listener: _onState,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: colors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: colors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpace.s4,
            children: [
              Text(
                'Delete a student',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Text(
                'Permanently removes the student account and all of their '
                'progress, attempts and conversations. This cannot be undone.',
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _email,
                builder: (context, value, _) =>
                    BlocBuilder<DeleteStudentCubit, DeleteStudentState>(
                      buildWhen: (a, b) =>
                          (a is DeleteStudentInProgress) !=
                          (b is DeleteStudentInProgress),
                      builder: (context, state) {
                        final busy = state is DeleteStudentInProgress;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: AppSpace.s4,
                          children: [
                            TextField(
                              key: const ValueKey('delete-student-email'),
                              controller: _email,
                              enabled: !busy,
                              keyboardType: TextInputType.emailAddress,
                              textDirection: TextDirection.ltr,
                              decoration: const InputDecoration(
                                labelText: 'Student email',
                              ),
                            ),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: colors.danger,
                                  foregroundColor: colors.onDanger,
                                ),
                                onPressed: busy || value.text.trim().isEmpty
                                    ? null
                                    : () => unawaited(_confirm()),
                                child: busy
                                    ? const SizedBox.square(
                                        dimension: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Delete student'),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmDeleteDialog extends StatefulWidget {
  const _ConfirmDeleteDialog({required this.email});
  final String email;
  @override
  State<_ConfirmDeleteDialog> createState() => _ConfirmDeleteDialogState();
}

class _ConfirmDeleteDialogState extends State<_ConfirmDeleteDialog> {
  late final TextEditingController _typed;
  @override
  void initState() {
    super.initState();
    _typed = TextEditingController();
  }

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AppDialog(
      title: 'Delete this student?',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpace.s3,
        children: [
          Text(
            'This permanently deletes the account for ${widget.email} and all '
            'of its data. It cannot be undone.',
          ),
          TextField(
            key: const ValueKey('delete-student-confirm'),
            controller: _typed,
            autofocus: true,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'Retype the email to confirm',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _typed,
          builder: (context, value, _) => FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.danger,
              foregroundColor: colors.onDanger,
            ),
            onPressed:
                DeleteStudentCubit.confirmationMatches(widget.email, value.text)
                ? () => Navigator.of(context).pop(true)
                : null,
            child: const Text('Delete permanently'),
          ),
        ),
      ],
    );
  }
}
