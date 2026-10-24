import 'package:flutter/material.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/import_copy.dart';

class EditorDropdown extends StatelessWidget {
  const EditorDropdown({
    required this.field,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
    this.problems = const [],
    super.key,
  });
  final String field;
  final String label;
  final String? value;
  final List<(String, String)> options;
  final ValueChanged<String?> onChanged;
  final bool enabled;
  final List<String> problems;
  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(
      labelText: label,
      errorText: problems.isEmpty
          ? null
          : problems.map(importProblemCopy).join('\n'),
      errorMaxLines: 3,
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        key: ValueKey('editor-$field'),
        isExpanded: true,
        isDense: true,
        value: options.any((o) => o.$1 == value) ? value : null,
        onChanged: enabled ? onChanged : null,
        items: [
          const DropdownMenuItem(child: Text('Select')),
          for (final (id, label) in options)
            DropdownMenuItem(
              value: id,
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
    ),
  );
}
