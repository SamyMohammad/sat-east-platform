import 'package:flutter/material.dart';

import 'package:sat_east_client/shared/widgets/app_dialog.dart';

class NotesTitleDialog extends StatefulWidget {
  const NotesTitleDialog({required this.title, super.key});
  final String title;
  @override
  State<NotesTitleDialog> createState() => _NotesTitleDialogState();
}

class _NotesTitleDialogState extends State<NotesTitleDialog> {
  late final TextEditingController _title;
  final _form = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.title);
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _save() {
    if (_form.currentState!.validate()) {
      Navigator.of(context).pop(_title.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: 'Rename',
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _title,
        autofocus: true,
        maxLength: 120,
        textDirection: TextDirection.ltr,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(labelText: 'Title'),
        validator: (value) =>
            value == null || value.trim().isEmpty ? 'Enter a title.' : null,
        onFieldSubmitted: (_) => _save(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save')),
    ],
  );
}
