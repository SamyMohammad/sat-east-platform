import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/text/text_direction.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/teacher/notes/domain/entities/teacher_note.dart';
import 'package:sat_east_client/features/teacher/notes/presentation/cubit/teacher_notes_cubit.dart';
import 'package:sat_east_client/features/teacher/notes/presentation/widgets/notes_title_dialog.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/topic_option.dart';

class TeacherNoteCard extends StatelessWidget {
  const TeacherNoteCard({
    required this.note,
    required this.subtopics,
    required this.busy,
    required this.first,
    required this.last,
    super.key,
  });
  final TeacherNote note;
  final List<SubtopicOption> subtopics;
  final bool busy;
  final bool first;
  final bool last;
  Future<void> _rename(BuildContext context) async {
    final cubit = context.read<TeacherNotesCubit>();
    final title = await showDialog<String>(
      context: context,
      builder: (_) => NotesTitleDialog(title: note.title),
    );
    if (context.mounted && title != null) await cubit.rename(note, title);
  }

  Future<void> _delete(BuildContext context) async {
    final cubit = context.read<TeacherNotesCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete'),
        content: Text(
          "Delete ${note.title}? This can't be undone.",
          textDirection: detectTextDirection(note.title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (context.mounted && confirmed == true) await cubit.delete(note);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TeacherNotesCubit>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(BookletSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: BookletSpace.s3,
          children: [
            Text(
              note.title,
              textDirection: detectTextDirection(note.title),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text('${note.pageCount} pages${note.ready ? '' : ' \u00b7 Draft'}'),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Subtopic'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  key: ValueKey('subtopic-${note.id}'),
                  value: note.subtopicId,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String>(child: Text('Whole topic')),
                    for (final subtopic in subtopics)
                      DropdownMenuItem(
                        value: subtopic.id,
                        child: Text(
                          subtopic.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textDirection: detectTextDirection(subtopic.title),
                        ),
                      ),
                  ],
                  onChanged: busy
                      ? null
                      : (value) => unawaited(cubit.setSubtopic(note, value)),
                ),
              ),
            ),
            Wrap(
              spacing: BookletSpace.s2,
              children: [
                TextButton(
                  key: ValueKey('rename-${note.id}'),
                  onPressed: busy ? null : () => unawaited(_rename(context)),
                  child: const Text('Rename'),
                ),
                IconButton(
                  key: ValueKey('up-${note.id}'),
                  tooltip: 'Move up',
                  onPressed: busy || first
                      ? null
                      : () => unawaited(cubit.move(note.id, -1)),
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  key: ValueKey('down-${note.id}'),
                  tooltip: 'Move down',
                  onPressed: busy || last
                      ? null
                      : () => unawaited(cubit.move(note.id, 1)),
                  icon: const Icon(Icons.arrow_downward),
                ),
                IconButton(
                  key: ValueKey('delete-${note.id}'),
                  tooltip: 'Delete',
                  onPressed: busy ? null : () => unawaited(_delete(context)),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
