import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/teacher/shell/teacher_animated_rows.dart';
import 'package:sat_east_client/features/teacher/videos/presentation/cubit/teacher_videos_cubit.dart';
import 'package:sat_east_client/features/teacher/videos/presentation/cubit/teacher_videos_state.dart';
import 'package:sat_east_client/features/teacher/videos/presentation/teacher_videos_copy.dart';
import 'package:sat_east_client/features/teacher/videos/presentation/widgets/teacher_video_card.dart';
import 'package:sat_east_client/features/teacher/videos/presentation/widgets/upload_video_dialog.dart';
import 'package:sat_east_client/shared/widgets/app_illustration.dart';
import 'package:sat_east_client/shared/widgets/empty_state.dart';

class TeacherVideosContent extends StatelessWidget {
  const TeacherVideosContent({
    required this.state,
    required this.topicId,
    required this.onReload,
    super.key,
  });
  final TeacherVideosReady state;
  final String topicId;
  final VoidCallback onReload;

  Future<void> _upload(BuildContext context) async {
    final cubit = context.read<TeacherVideosCubit>();
    await showUploadVideoDialog(
      context,
      topicId: topicId,
      onPublished: () => unawaited(cubit.load(topicId)),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpace.s3,
          children: [
            Row(
              children: [
                Expanded(child: Text(state.data.quota.label)),
                IconButton(
                  tooltip: TeacherVideosCopy.reload,
                  onPressed: state.busy ? null : onReload,
                  icon: const Icon(AppIcons.retry),
                ),
              ],
            ),
            LinearProgressIndicator(value: state.data.quota.fraction),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.icon(
                onPressed: state.busy
                    ? null
                    : () => unawaited(_upload(context)),
                icon: const Icon(AppIcons.upload),
                label: const Text(TeacherVideosCopy.uploadVideo),
              ),
            ),
          ],
        ),
      ),
      if (state.busy) const LinearProgressIndicator(),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: TeacherAnimatedRows(
            emptyState: const EmptyState(
              title: TeacherVideosCopy.empty,
              message: '',
              illustration: AppIllustrationName.emptyCourses,
            ),
            children: [
              for (var index = 0; index < state.data.videos.length; index++)
                TeacherVideoCard(
                  key: ValueKey(
                    'video-${state.data.videos[index].assetId}',
                  ),
                  video: state.data.videos[index],
                  busy: state.busy,
                  first: index == 0,
                  last: index == state.data.videos.length - 1,
                ),
            ],
          ),
        ),
      ),
    ],
  );
}
