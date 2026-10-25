import 'package:flutter/material.dart';

import 'package:sat_east_client/core/text/text_direction.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';

import 'package:sat_east_client/features/topic/domain/entities/topic_video.dart';
import 'package:sat_east_client/features/topic/presentation/topic_copy.dart';

class TopicVideoStep extends StatelessWidget {
  const TopicVideoStep({
    required this.videos,
    required this.done,
    this.onOpen,
    super.key,
  });

  final List<TopicVideo> videos;
  final bool done;
  final ValueChanged<TopicVideo>? onOpen;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(BookletSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                TopicCopy.video,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (done)
                const Padding(
                  padding: EdgeInsetsDirectional.only(start: BookletSpace.s2),
                  child: Icon(Icons.check_circle_outline),
                ),
            ],
          ),
          for (final video in videos)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                video.title,
                textDirection: detectTextDirection(video.title),
              ),
              subtitle: Text(
                TopicCopy.videoProgress(
                  video.durationS,
                  video.pct,
                  video.subtopicTitle,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: onOpen == null ? null : () => onOpen!(video),
            ),
        ],
      ),
    ),
  );
}
