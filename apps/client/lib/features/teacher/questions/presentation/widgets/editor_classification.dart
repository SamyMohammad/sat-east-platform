import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/topic_option.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/bank_copy.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_editor_cubit.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_editor_state.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/widgets/editor_dropdown.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/widgets/editor_field.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/widgets/editor_section.dart';

typedef _Classification = ({
  String courses,
  String topic,
  String subtopic,
  String difficulty,
  String pool,
  String status,
  bool desmos,
  bool enabled,
  List<BankCourse> topics,
  Map<String, List<String>> errors,
});

class EditorClassification extends StatelessWidget {
  const EditorClassification({super.key});
  @override
  Widget build(
    BuildContext context,
  ) => BlocSelector<QuestionEditorCubit, QuestionEditorState, _Classification>(
    selector: (s) => (
      courses: s.draft?.courseCodes.join(',') ?? '',
      topic: s.draft?.topicSlug ?? '',
      subtopic: s.draft?.subtopicSlug ?? '',
      difficulty: s.draft?.difficulty ?? '',
      pool: s.draft?.pool ?? '',
      status: s.draft?.status ?? '',
      desmos: s.draft?.desmosFriendly ?? false,
      enabled: !s.saving,
      topics: s.topics,
      errors: s.serverErrors,
    ),
    builder: (context, s) {
      final cubit = context.read<QuestionEditorCubit>();
      final draft = cubit.state.draft!;
      final primary = draft.courseCodes.firstOrNull;
      final topics = s.topics
          .where((c) => c.courseCode == primary)
          .expand((c) => c.topics)
          .toList();
      final subs = topics
          .where((t) => t.slug == s.topic)
          .expand((t) => t.subtopics)
          .toList();
      return EditorSection(
        title: 'Classification',
        children: [
          EditorDropdown(
            field: 'course_codes',
            label: 'Primary course',
            value: primary,
            options: [for (final c in s.topics) (c.courseCode, c.courseCode)],
            enabled: s.enabled,
            problems: s.errors['course_codes'] ?? const [],
            onChanged: (code) {
              final current = cubit.state.draft!.courseCodes;
              cubit.editClassification(
                courseCodes: code == null
                    ? []
                    : [code, ...current.where((v) => v != code)],
              );
            },
          ),
          Wrap(
            spacing: BookletSpace.s2,
            children: [
              for (final course in s.topics)
                if (course.courseCode != primary)
                  FilterChip(
                    label: Text(course.courseCode),
                    selected: draft.courseCodes.contains(course.courseCode),
                    onSelected: s.enabled
                        ? (selected) {
                            final current = cubit.state.draft!.courseCodes;
                            cubit.editClassification(
                              courseCodes: selected
                                  ? [...current, course.courseCode]
                                  : current
                                        .where((v) => v != course.courseCode)
                                        .toList(),
                            );
                          }
                        : null,
                  ),
            ],
          ),
          EditorDropdown(
            field: 'topic_slug',
            label: 'Topic',
            value: s.topic,
            options: [for (final t in topics) (t.slug, t.title)],
            enabled: s.enabled,
            problems: s.errors['topic_slug'] ?? const [],
            onChanged: (v) => cubit.editClassification(topicSlug: v ?? ''),
          ),
          EditorDropdown(
            field: 'subtopic_slug',
            label: 'Subtopic',
            value: s.subtopic,
            options: [for (final sub in subs) (sub.slug, sub.title)],
            enabled: s.enabled,
            problems: s.errors['subtopic_slug'] ?? const [],
            onChanged: (v) => cubit.editClassification(subtopicSlug: v ?? ''),
          ),
          EditorField(
            field: 'skill_codes',
            label: 'Skills (comma-separated)',
            read: (d) => d.skillCodes.join(','),
            change: (c, v) =>
                c.editClassification(skillCodes: v.isEmpty ? [] : v.split(',')),
          ),
          EditorDropdown(
            field: 'difficulty',
            label: 'Difficulty',
            value: s.difficulty,
            options: const [('E', 'E'), ('M', 'M'), ('H', 'H')],
            enabled: s.enabled,
            problems: s.errors['difficulty'] ?? const [],
            onChanged: (v) => cubit.editClassification(difficulty: v ?? ''),
          ),
          EditorDropdown(
            field: 'pool',
            label: 'Pool',
            value: s.pool,
            options: [
              for (final v in ['practice', 'quiz', 'mock_reserve'])
                (v, bankValueLabel(v)),
            ],
            enabled: s.enabled,
            problems: s.errors['pool'] ?? const [],
            onChanged: (v) => cubit.editClassification(pool: v ?? ''),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Desmos friendly'),
            value: s.desmos,
            onChanged: s.enabled
                ? (v) => cubit.editClassification(desmosFriendly: v)
                : null,
          ),
          EditorDropdown(
            field: 'status',
            label: 'Status',
            value: s.status,
            options: [
              for (final v in [
                'draft',
                'solved',
                'needs_review',
                'approved',
                'published',
                'retired',
              ])
                (v, bankValueLabel(v)),
            ],
            enabled: s.enabled,
            problems: s.errors['status'] ?? const [],
            onChanged: (v) => cubit.editClassification(status: v ?? ''),
          ),
        ],
      );
    },
  );
}
