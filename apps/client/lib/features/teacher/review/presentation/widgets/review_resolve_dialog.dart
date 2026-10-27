import 'package:flutter/material.dart';

import 'package:sat_east_client/shared/widgets/app_dialog.dart';

Future<({String? note})?> showReviewResolveDialog(
  BuildContext context,
  String outcome,
) => showDialog<({String? note})>(
  context: context,
  builder: (_) => _ResolveDialog(outcome: outcome),
);

class _ResolveDialog extends StatefulWidget {
  const _ResolveDialog({required this.outcome});
  final String outcome;
  @override
  State<_ResolveDialog> createState() => _ResolveDialogState();
}

class _ResolveDialogState extends State<_ResolveDialog> {
  late final TextEditingController _note;
  @override
  void initState() {
    super.initState();
    _note = TextEditingController();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.outcome == 'fixed' ? 'Mark fixed' : 'Not a problem';
    return AppDialog(
      title: action,
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('This closes all open reports for this question.'),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _note,
                builder: (context, value, _) => TextField(
                  controller: _note,
                  maxLength: 500,
                  minLines: 2,
                  maxLines: 4,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(labelText: 'Optional note'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _note,
          builder: (context, value, _) => FilledButton(
            onPressed: value.text.length > 500
                ? null
                : () => Navigator.of(context).pop((
                    note: _note.text,
                  )),
            child: Text(action),
          ),
        ),
      ],
    );
  }
}
