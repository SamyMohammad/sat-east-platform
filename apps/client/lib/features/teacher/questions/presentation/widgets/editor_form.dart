import 'package:flutter/material.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/widgets/editor_answer.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/widgets/editor_classification.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/widgets/editor_field.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/widgets/editor_section.dart';

class EditorForm extends StatelessWidget {
  const EditorForm({super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: BookletSpace.s4,
    children: [
      EditorSection(
        title: 'Content',
        children: [
          EditorField(
            field: 'stem_md',
            label: 'Stem',
            multiline: true,
            read: (d) => d.stemMd,
            change: (c, v) => c.editContent(stemMd: v),
          ),
          EditorField(
            field: 'hint_md',
            label: 'Hint',
            multiline: true,
            read: (d) => d.hintMd,
            change: (c, v) => c.editContent(hintMd: v),
          ),
          EditorField(
            field: 'explanation_md',
            label: 'Explanation',
            multiline: true,
            read: (d) => d.explanationMd,
            change: (c, v) => c.editContent(explanationMd: v),
          ),
          EditorField(
            field: 'images',
            label: 'Image paths (one per line)',
            multiline: true,
            read: (d) => d.images.join('\n'),
            change: (c, v) =>
                c.editContent(images: v.isEmpty ? [] : v.split('\n')),
          ),
        ],
      ),
      const EditorAnswer(),
      const EditorClassification(),
      EditorSection(
        title: 'Source',
        children: [
          EditorField(
            field: 'external_ref',
            label: 'External ref',
            read: (d) => d.externalRef,
            change: (c, v) => c.editSource(externalRef: v),
          ),
          EditorField(
            field: 'source',
            label: 'Source',
            read: (d) => d.source,
            change: (c, v) => c.editSource(source: v),
          ),
          EditorField(
            field: 'source_page',
            label: 'Source page',
            numeric: true,
            read: (d) => d.sourcePage,
            change: (c, v) => c.editSource(sourcePage: v),
          ),
          EditorField(
            field: 'solved_by',
            label: 'Solved by (teacher, ai_double_agree, ai_teacher_fixed)',
            read: (d) => d.solvedBy,
            change: (c, v) => c.editSource(solvedBy: v),
          ),
        ],
      ),
    ],
  );
}
