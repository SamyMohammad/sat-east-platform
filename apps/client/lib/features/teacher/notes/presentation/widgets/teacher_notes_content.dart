import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/text/text_direction.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/teacher/notes/presentation/cubit/teacher_notes_cubit.dart';
import 'package:sat_east_client/features/teacher/notes/presentation/cubit/teacher_notes_state.dart';
import 'package:sat_east_client/features/teacher/notes/presentation/widgets/teacher_note_card.dart';

class TeacherNotesContent extends StatelessWidget {
  const TeacherNotesContent({required this.state, super.key});
  final TeacherNotesReady state;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.all(BookletSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: BookletSpace.s3,
          children: [
            Text(
              state.data.topicTitle,
              textDirection: detectTextDirection(state.data.topicTitle),
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
        child: state.data.notes.isEmpty
            ? const Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.all(BookletSpace.s4),
                  child: Text('No notes yet.'),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(BookletSpace.s4),
                itemCount: state.data.notes.length,
                itemBuilder: (context, index) => TeacherNoteCard(
                  key: ValueKey(state.data.notes[index].id),
                  note: state.data.notes[index],
                  subtopics: state.data.subtopics,
                  busy: state.busy,
                  first: index == 0,
                  last: index == state.data.notes.length - 1,
                ),
              ),
      ),
    ],
  );
}
