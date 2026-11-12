import 'package:flutter/material.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/mock_copy.dart';
import 'package:sat_east_client/shared/widgets/app_dialog.dart';

/// Confirm dialog; false when the teacher cancels or dismisses it.
Future<bool> confirmMockAction(
  BuildContext context, {
  required String title,
  required String body,
  required String actionLabel,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: title,
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(mockCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(actionLabel),
          ),
        ],
      ),
    ) ??
    false;
