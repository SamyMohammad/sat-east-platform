import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:sat_east_client/core/theme/app_motion.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_editor_cubit.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_editor_state.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/widgets/editor_answer.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/widgets/editor_classification.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/widgets/editor_error_summary.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/widgets/editor_field.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/widgets/editor_field_anchor.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/widgets/editor_section.dart';

class EditorForm extends StatefulWidget {
  const EditorForm({super.key});
  @override
  State<EditorForm> createState() => _EditorFormState();
}

class _EditorFormState extends State<EditorForm> {
  late final Map<String, GlobalKey> _targets;
  final GlobalKey _summaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _targets = {
      for (final field in editorProblemFieldLabels.keys) field: GlobalKey(),
    };
  }

  void _jumpTo(String field) {
    final targetContext =
        _targets[field == 'misconceptions' ? 'choices' : field]
            ?.currentContext ??
        _targets['stem_md']!.currentContext;
    if (targetContext != null) {
      unawaited(
        Scrollable.ensureVisible(
          targetContext,
          duration: AppMotion.resolve(context, AppMotion.state),
          curve: AppMotion.standard,
        ),
      );
    }
  }

  void _showSummary() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final summaryContext = _summaryKey.currentContext;
      if (summaryContext != null) {
        unawaited(
          Scrollable.ensureVisible(
            summaryContext,
            duration: AppMotion.resolve(context, AppMotion.state),
            curve: AppMotion.standard,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => EditorFieldTargets(
    targets: _targets,
    child: BlocListener<QuestionEditorCubit, QuestionEditorState>(
      listenWhen: (previous, next) =>
          previous.saving && !next.saving && next.serverErrors.isNotEmpty,
      listener: (_, _) => _showSummary(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpace.s4,
        children: [
          EditorErrorSummary(key: _summaryKey, onJump: _jumpTo),
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
      ),
    ),
  );
}
