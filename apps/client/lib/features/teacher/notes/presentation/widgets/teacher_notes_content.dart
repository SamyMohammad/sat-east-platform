import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/teacher/notes/presentation/cubit/teacher_notes_cubit.dart';
import 'package:sat_east_client/features/teacher/notes/presentation/cubit/teacher_notes_state.dart';
import 'package:sat_east_client/features/teacher/notes/presentation/widgets/teacher_note_card.dart';
import 'package:sat_east_client/features/teacher/shell/teacher_animated_rows.dart';
import 'package:sat_east_client/shared/widgets/app_illustration.dart';
import 'package:sat_east_client/shared/widgets/empty_state.dart';

class TeacherNotesContent extends StatelessWidget {
  const TeacherNotesContent({required this.state, super.key});
  final TeacherNotesReady state;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpace.s3,
          children: [
            Text(
              state.data.topicTitle,
              textDirection: TextDirection.ltr,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            FilledButton.icon(
              onPressed: state.busy
                  ? null
                  : () => unawaited(
                      context.read<TeacherNotesCubit>().pickAndUpload(),
                    ),
              icon: const Icon(AppIcons.upload),
              label: const Text('Upload PDF'),
            ),
            Text('PDF up to ${state.data.maxMb} MB'),
          ],
        ),
      ),
      if (state.busy) const LinearProgressIndicator(),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: TeacherAnimatedRows(
            emptyState: const EmptyState(
              title: 'No notes yet.',
              message: '',
              illustration: AppIllustrationName.emptyCourses,
            ),
            children: [
              for (var index = 0; index < state.data.notes.length; index++)
                TeacherNoteCard(
                  key: ValueKey(state.data.notes[index].id),
                  note: state.data.notes[index],
                  subtopics: state.data.subtopics,
                  busy: state.busy,
                  first: index == 0,
                  last: index == state.data.notes.length - 1,
                ),
            ],
          ),
        ),
      ),
    ],
  );
}
