import 'package:flutter/material.dart';
import 'package:sat_east_client/core/text/text_direction.dart';

class BuilderTitleDialog extends StatefulWidget {
  const BuilderTitleDialog({required this.label, super.key});
  final String label;
  @override
  State<BuilderTitleDialog> createState() => _BuilderTitleDialogState();
}

class _BuilderTitleDialogState extends State<BuilderTitleDialog> {
  final _controller = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) {
      Navigator.of(context).pop(_controller.text);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.label),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _controller,
        autofocus: true,
        maxLength: 120,
        decoration: const InputDecoration(labelText: 'Title'),
        textDirection: detectTextDirection(_controller.text),
        onChanged: (_) => setState(() {}),
        validator: (value) =>
            value == null || value.trim().isEmpty ? 'Enter a title.' : null,
        onFieldSubmitted: (_) => _submit(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: Text(widget.label)),
    ],
  );
}
