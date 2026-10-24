import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/question_draft.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_editor_cubit.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_editor_state.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/import_copy.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/widgets/editor_dropdown.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/widgets/editor_field.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/widgets/editor_section.dart';

class EditorAnswer extends StatelessWidget {
  const EditorAnswer({super.key});
  @override
  Widget build(BuildContext context) =>
      BlocSelector<
        QuestionEditorCubit,
        QuestionEditorState,
        ({String type, bool enabled, Map<String, List<String>> errors})
      >(
        selector: (s) => (
          type: s.draft?.type ?? 'mcq',
          enabled: !s.saving,
          errors: s.serverErrors,
        ),
        builder: (context, s) => EditorSection(
          title: 'Answer',
          children: [
            EditorDropdown(
              field: 'type',
              label: 'Question type',
              value: s.type,
              enabled: s.enabled,
              problems: s.errors['type'] ?? const [],
              options: const [('mcq', 'MCQ'), ('spr', 'SPR')],
              onChanged: (value) => context
                  .read<QuestionEditorCubit>()
                  .editAnswer(type: value ?? ''),
            ),
            if (s.type == 'spr') ...[
              EditorField(
                field: 'accepted',
                label: 'Accepted answers (one per line)',
                multiline: true,
                read: (d) => d.accepted.join('\n'),
                change: (c, v) =>
                    c.editAnswer(accepted: v.isEmpty ? [] : v.split('\n')),
              ),
              EditorField(
                field: 'tolerance',
                label: 'Tolerance',
                numeric: true,
                read: (d) => d.tolerance,
                change: (c, v) => c.editAnswer(tolerance: v),
              ),
            ] else
              const _McqChoices(),
            for (final problem in s.errors['key'] ?? const <String>[])
              Text(
                importProblemCopy(problem),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            for (final problem in s.errors['choices'] ?? const <String>[])
              Text(
                importProblemCopy(problem),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      );
}

class _McqChoices extends StatelessWidget {
  const _McqChoices();
  @override
  Widget build(BuildContext context) =>
      BlocSelector<QuestionEditorCubit, QuestionEditorState, String>(
        selector: (s) => s.draft?.keyChoice ?? '',
        builder: (context, keyChoice) => RadioGroup<String>(
          groupValue: keyChoice,
          onChanged: (value) => context.read<QuestionEditorCubit>().editAnswer(
            keyChoice: value ?? '',
          ),
          child: const Column(
            children: [
              _ChoiceEditor('A'),
              _ChoiceEditor('B'),
              _ChoiceEditor('C'),
              _ChoiceEditor('D'),
              _ChoiceEditor('E'),
            ],
          ),
        ),
      );
}

class _ChoiceEditor extends StatelessWidget {
  const _ChoiceEditor(this.label);
  final String label;
  @override
  Widget build(BuildContext context) =>
      BlocSelector<
        QuestionEditorCubit,
        QuestionEditorState,
        ({
          DraftChoice? choice,
          String misconception,
          bool enabled,
          bool correct,
        })
      >(
        selector: (s) => (
          choice: s.draft?.choices.where((c) => c.label == label).firstOrNull,
          misconception: s.draft?.misconceptions[label]?.toString() ?? '',
          enabled: !s.saving,
          correct: s.draft?.keyChoice == label,
        ),
        builder: (context, s) {
          final cubit = context.read<QuestionEditorCubit>();
          return Padding(
            padding: const EdgeInsets.only(bottom: BookletSpace.s4),
            child: Column(
              spacing: BookletSpace.s3,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: s.choice != null,
                      onChanged: s.enabled
                          ? (included) {
                              final choices = cubit.state.draft!.choices;
                              cubit.editAnswer(
                                choices: included == true
                                    ? [
                                        ...choices,
                                        DraftChoice(label: label, body: ''),
                                      ]
                                    : choices
                                          .where((c) => c.label != label)
                                          .toList(),
                              );
                            }
                          : null,
                    ),
                    Text('Choice $label'),
                    const Spacer(),
                    const Text('Key'),
                    Radio<String>(
                      key: ValueKey('editor-key-$label'),
                      value: label,
                      enabled: s.enabled && s.choice != null,
                    ),
                  ],
                ),
                if (s.choice != null) ...[
                  EditorTextInput(
                    field: 'choice-$label',
                    label: 'Choice $label text',
                    value: s.choice!.body,
                    enabled: s.enabled,
                    onChanged: (value) => cubit.editChoice(label, body: value),
                  ),
                  if (!s.correct)
                    EditorTextInput(
                      field: 'misconception-$label',
                      label: 'Choice $label misconception',
                      value: s.misconception,
                      enabled: s.enabled,
                      onChanged: (value) =>
                          cubit.editChoice(label, misconception: value),
                    ),
                ],
              ],
            ),
          );
        },
      );
}
