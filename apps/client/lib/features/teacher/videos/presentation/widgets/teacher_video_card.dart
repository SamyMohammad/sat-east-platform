import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/text/text_direction.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/teacher_video.dart';
import 'package:sat_east_client/features/teacher/videos/presentation/cubit/teacher_videos_cubit.dart';
import 'package:sat_east_client/features/teacher/videos/presentation/teacher_videos_copy.dart';
import 'package:sat_east_client/features/teacher/videos/presentation/widgets/video_title_dialog.dart';
import 'package:sat_east_client/shared/widgets/booklet_chip.dart';

class TeacherVideoCard extends StatelessWidget {
  const TeacherVideoCard({
    required this.video,
    required this.busy,
    required this.first,
    required this.last,
    super.key,
  });
  final TeacherVideo video;
  final bool busy;
  final bool first;
  final bool last;

  Future<void> _rename(BuildContext context) async {
    final cubit = context.read<TeacherVideosCubit>();
    final title = await showDialog<String>(
      context: context,
      builder: (_) => VideoTitleDialog(title: video.title),
    );
    if (context.mounted && title != null) {
      await cubit.rename(video.assetId, title);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final cubit = context.read<TeacherVideosCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(TeacherVideosCopy.delete),
        content: const Text(TeacherVideosCopy.deleteWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(TeacherVideosCopy.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(TeacherVideosCopy.delete),
          ),
        ],
      ),
    );
    if (context.mounted && confirmed == true) await cubit.delete(video.assetId);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TeacherVideosCubit>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(BookletSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: BookletSpace.s3,
          children: [
            Text(
              video.title,
              textDirection: detectTextDirection(video.title),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (video.subtopicTitle case final title?)
              Text(title, textDirection: detectTextDirection(title)),
            Wrap(
              spacing: BookletSpace.s3,
              runSpacing: BookletSpace.s2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(TeacherVideosCopy.duration(video.durationS)),
                Text(TeacherVideosCopy.size(video.sizeMb, video.provider)),
                BookletChip(label: TeacherVideosCopy.provider(video.provider)),
              ],
            ),
            if (!video.ready) const Text(TeacherVideosCopy.pending),
            Wrap(
              spacing: BookletSpace.s2,
              children: [
                if (video.ready) ...[
                  TextButton(
                    key: ValueKey('rename-${video.assetId}'),
                    onPressed: busy ? null : () => unawaited(_rename(context)),
                    child: const Text(TeacherVideosCopy.rename),
                  ),
                  IconButton(
                    key: ValueKey('up-${video.assetId}'),
                    tooltip: TeacherVideosCopy.moveUp,
                    onPressed: busy || first
                        ? null
                        : () => unawaited(cubit.moveUp(video.assetId)),
                    icon: const Icon(Icons.arrow_upward),
                  ),
                  IconButton(
                    key: ValueKey('down-${video.assetId}'),
                    tooltip: TeacherVideosCopy.moveDown,
                    onPressed: busy || last
                        ? null
                        : () => unawaited(cubit.moveDown(video.assetId)),
                    icon: const Icon(Icons.arrow_downward),
                  ),
                ],
                IconButton(
                  key: ValueKey('delete-${video.assetId}'),
                  tooltip: TeacherVideosCopy.delete,
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
