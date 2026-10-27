import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sat_east_client/core/text/text_direction.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/shared/widgets/app_overlays.dart';

typedef ReportProblem = ({String reason, String? note});

Future<ReportProblem?> showReportProblemSheet(
  BuildContext context, {
  required Map<String, String> reasons,
}) {
  if (MediaQuery.sizeOf(context).width < 600) {
    return showAppSheet<ReportProblem>(
      context: context,
      builder: (_) => ReportProblemSheet(reasons: reasons),
    );
  }
  return showAppDialog<ReportProblem>(
    context: context,
    builder: (_) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: BookletSize.dialogWidth),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(BookletSpace.s5),
            child: ReportProblemSheet(reasons: reasons),
          ),
        ),
      ),
    ),
  );
}

class ReportProblemSheet extends StatefulWidget {
  const ReportProblemSheet({required this.reasons, super.key});
  final Map<String, String> reasons;
  @override
  State<ReportProblemSheet> createState() => _ReportProblemSheetState();
}

class _ReportProblemSheetState extends State<ReportProblemSheet> {
  late final TextEditingController _note;
  final _form = GlobalKey<FormState>();
  String? _reason;
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

  void _submit() {
    final reason = _reason;
    if (reason == null || !_form.currentState!.validate()) return;
    final note = _note.text.trim();
    Navigator.of(
      context,
    ).pop<ReportProblem>((reason: reason, note: note.isEmpty ? null : note));
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BookletSpace.s3,
      children: [
        Text('Report a problem', style: Theme.of(context).textTheme.titleLarge),
        RadioGroup<String>(
          groupValue: _reason,
          onChanged: (value) => setState(() => _reason = value),
          child: Column(
            children: [
              for (final reason in widget.reasons.entries)
                RadioListTile<String>(
                  value: reason.key,
                  title: Text(reason.value),
                  contentPadding: EdgeInsets.zero,
                ),
            ],
          ),
        ),
        TextFormField(
          controller: _note,
          minLines: 2,
          maxLines: 4,
          maxLength: 500,
          maxLengthEnforcement: MaxLengthEnforcement.none,
          buildCounter:
              (
                context, {
                required currentLength,
                required isFocused,
                maxLength,
              }) => Text('${_note.text.trim().runes.length}/500'),
          textDirection: detectTextDirection(_note.text),
          decoration: const InputDecoration(labelText: 'Note (optional)'),
          onChanged: (_) => setState(() {}),
          validator: (value) => (value?.trim().runes.length ?? 0) > 500
              ? 'The note must be 500 characters or fewer.'
              : null,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          spacing: BookletSpace.s2,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: _reason == null ? null : _submit,
              child: const Text('Submit'),
            ),
          ],
        ),
      ],
    ),
  );
}
