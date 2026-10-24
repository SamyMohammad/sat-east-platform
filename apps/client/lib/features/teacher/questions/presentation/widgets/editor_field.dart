import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/text/text_direction.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/question_draft.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_editor_cubit.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_editor_state.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/import_copy.dart';

typedef EditorTextSelection = ({String value, String? error, bool enabled});

class EditorField extends StatelessWidget {
  const EditorField({
    required this.field,
    required this.label,
    required this.read,
    required this.change,
    this.multiline = false,
    this.numeric = false,
    super.key,
  });
  final String field;
  final String label;
  final String Function(QuestionDraft) read;
  final void Function(QuestionEditorCubit, String) change;
  final bool multiline;
  final bool numeric;
  @override
  Widget build(BuildContext context) =>
      BlocSelector<
        QuestionEditorCubit,
        QuestionEditorState,
        EditorTextSelection
      >(
        selector: (state) {
          final problems = state.serverErrors[field] ?? const <String>[];
          return (
            value: state.draft == null ? '' : read(state.draft!),
            error: problems.isEmpty
                ? null
                : problems.map(importProblemCopy).join('\n'),
            enabled: !state.loading && !state.saving,
          );
        },
        builder: (context, selected) => EditorTextInput(
          field: field,
          label: label,
          value: selected.value,
          error: selected.error,
          enabled: selected.enabled,
          multiline: multiline,
          numeric: numeric,
          onChanged: (value) =>
              change(context.read<QuestionEditorCubit>(), value),
        ),
      );
}

class EditorTextInput extends StatefulWidget {
  const EditorTextInput({
    required this.field,
    required this.label,
    required this.value,
    required this.onChanged,
    this.error,
    this.enabled = true,
    this.multiline = false,
    this.numeric = false,
    super.key,
  });
  final String field;
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? error;
  final bool enabled;
  final bool multiline;
  final bool numeric;
  @override
  State<EditorTextInput> createState() => _EditorTextInputState();
}

class _EditorTextInputState extends State<EditorTextInput> {
  late final TextEditingController _controller;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(EditorTextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) _controller.text = widget.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    key: ValueKey('editor-${widget.field}'),
    controller: _controller,
    enabled: widget.enabled,
    onChanged: widget.onChanged,
    textDirection: detectTextDirection(widget.value),
    minLines: widget.multiline ? 2 : 1,
    maxLines: widget.multiline ? 5 : 1,
    keyboardType: widget.numeric
        ? const TextInputType.numberWithOptions(decimal: true, signed: true)
        : widget.multiline
        ? TextInputType.multiline
        : TextInputType.text,
    decoration: InputDecoration(
      labelText: widget.label,
      errorText: widget.error,
      errorMaxLines: 3,
    ),
  );
}
