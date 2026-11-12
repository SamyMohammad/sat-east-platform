import 'package:flutter/material.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/mock_copy.dart';
import 'package:sat_east_client/shared/widgets/app_dialog.dart';

/// Asks which set the new form joins. Returns the set number, or null when
/// the teacher cancels.
Future<int?> showMockAssembleDialog(
  BuildContext context, {
  required List<int> existingSets,
}) => showDialog<int>(
  context: context,
  builder: (_) => _AssembleDialog(existingSets: existingSets),
);

class _AssembleDialog extends StatefulWidget {
  const _AssembleDialog({required this.existingSets});
  final List<int> existingSets;

  @override
  State<_AssembleDialog> createState() => _AssembleDialogState();
}

class _AssembleDialogState extends State<_AssembleDialog> {
  int _setNo = 1;

  @override
  Widget build(BuildContext context) {
    // Set 1 is always offered (the default); "next set" only once a set exists.
    final sets = ({1, ...widget.existingSets}.toList()..sort());
    final next = widget.existingSets.isEmpty ? null : sets.last + 1;
    return AppDialog(
      title: mockAssembleTitle,
      content: DropdownButtonFormField<int>(
        initialValue: _setNo,
        decoration: const InputDecoration(labelText: mockSetLabel),
        items: [
          for (final set in sets)
            DropdownMenuItem(value: set, child: Text(mockSetOption(set))),
          if (next != null)
            DropdownMenuItem(value: next, child: Text(mockNextSetOption(next))),
        ],
        onChanged: (value) => setState(() => _setNo = value ?? _setNo),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(mockCancel),
        ),
        const SizedBox(width: AppSpace.s1),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_setNo),
          child: const Text(mockAssembleConfirm),
        ),
      ],
    );
  }
}
