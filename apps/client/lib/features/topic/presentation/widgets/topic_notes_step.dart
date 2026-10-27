import 'package:flutter/material.dart';
import 'package:sat_east_client/core/text/text_direction.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_note.dart';
import 'package:sat_east_client/features/topic/presentation/topic_copy.dart';

class TopicNotesStep extends StatelessWidget {
  const TopicNotesStep({
    required this.notes,
    required this.done,
    this.onOpen,
    this.lockedByVideo = false,
    super.key,
  });
  final List<TopicNote> notes;
  final bool done;
  final bool lockedByVideo;
  final ValueChanged<TopicNote>? onOpen;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Text(
            TopicCopy.notes,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (done)
            const Padding(
              padding: EdgeInsetsDirectional.only(start: AppSpace.s2),
              child: Icon(AppIcons.correct),
            ),
        ],
      ),
      if (lockedByVideo) const Text(TopicCopy.watchVideoFirst),
      for (final note in notes)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            note.title,
            textDirection: detectTextDirection(note.title),
          ),
          subtitle: note.subtopicTitle == null && note.pageCount == null
              ? null
              : Text(
                  [
                    if (note.subtopicTitle != null) note.subtopicTitle!,
                    if (note.pageCount != null) '${note.pageCount} pages',
                  ].join(' \u00b7 '),
                ),
          trailing: const Icon(AppIcons.next),
          enabled: !lockedByVideo,
          onTap: lockedByVideo || onOpen == null ? null : () => onOpen!(note),
        ),
    ],
  );
}
