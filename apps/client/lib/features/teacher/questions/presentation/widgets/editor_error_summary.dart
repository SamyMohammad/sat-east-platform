import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_editor_cubit.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_editor_state.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/import_copy.dart';

const editorProblemFieldLabels = <String, String>{
  'stem_md': 'Stem',
  'hint_md': 'Hint',
  'explanation_md': 'Explanation',
  'images': 'Image paths',
  'type': 'Question type',
  'key': 'Answer key',
  'choices': 'Choices',
  'misconceptions': 'Misconceptions',
  'accepted': 'Accepted answers',
  'tolerance': 'Tolerance',
  'course_codes': 'Primary course',
  'topic_slug': 'Topic',
  'subtopic_slug': 'Subtopic',
  'skill_codes': 'Skills',
  'difficulty': 'Difficulty',
  'pool': 'Pool',
  'desmos_friendly': 'Desmos friendly',
  'status': 'Status',
  'external_ref': 'External ref',
  'source': 'Source',
  'source_page': 'Source page',
  'solved_by': 'Solved by',
};

class EditorErrorSummary extends StatelessWidget {
  const EditorErrorSummary({required this.onJump, super.key});
  final ValueChanged<String> onJump;

  static String _problemLine(String field, String problem) {
    final label = editorProblemFieldLabels[field] ?? field;
    return '$label: ${importProblemCopy(problem)}';
  }

  @override
  Widget build(BuildContext context) =>
      BlocSelector<
        QuestionEditorCubit,
        QuestionEditorState,
        Map<String, List<String>>
      >(
        selector: (state) => state.serverErrors,
        builder: (context, errors) {
          final count = errors.values.fold(
            0,
            (n, problems) => n + problems.length,
          );
          if (count == 0) return const SizedBox.shrink();
          return Material(
            key: const ValueKey('editor-error-summary'),
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(BookletSpace.s3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '$count ${count == 1 ? 'problem' : 'problems'} '
                    'to fix before saving.',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  for (final entry in errors.entries)
                    for (final problem in entry.value)
                      TextButton(
                        style: TextButton.styleFrom(
                          alignment: Alignment.centerLeft,
                        ),
                        onPressed: () => onJump(entry.key),
                        child: Text(
                          _problemLine(entry.key, problem),
                        ),
                      ),
                ],
              ),
            ),
          );
        },
      );
}
