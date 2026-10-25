import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/teacher/videos/presentation/cubit/teacher_videos_cubit.dart';
import 'package:sat_east_client/features/teacher/videos/presentation/cubit/teacher_videos_state.dart';
import 'package:sat_east_client/features/teacher/videos/presentation/teacher_videos_copy.dart';
import 'package:sat_east_client/features/teacher/videos/presentation/widgets/add_youtube_dialog.dart';
import 'package:sat_east_client/features/teacher/videos/presentation/widgets/teacher_video_card.dart';

class TeacherVideosContent extends StatelessWidget {
  const TeacherVideosContent({
    required this.state,
    required this.onReload,
    super.key,
  });
  final TeacherVideosReady state;
  final VoidCallback onReload;

  Future<void> _add(BuildContext context) async {
    final cubit = context.read<TeacherVideosCubit>();
    final draft = await showDialog<YoutubeVideoDraft>(
      context: context,
      builder: (_) => const AddYoutubeDialog(),
    );
    if (context.mounted && draft != null) {
      await cubit.addYoutube(
        title: draft.title,
        input: draft.input,
        durationS: draft.durationS,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.all(BookletSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: BookletSpace.s3,
          children: [
            Row(
              children: [
                Expanded(child: Text(state.data.quota.label)),
                IconButton(
                  tooltip: TeacherVideosCopy.reload,
                  onPressed: state.busy ? null : onReload,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            LinearProgressIndicator(value: state.data.quota.fraction),
            const Text(TeacherVideosCopy.upload),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.icon(
                onPressed: state.busy ? null : () => unawaited(_add(context)),
                icon: const Icon(Icons.add),
                label: const Text(TeacherVideosCopy.addYoutube),
              ),
            ),
          ],
        ),
      ),
      if (state.busy) const LinearProgressIndicator(),
      Expanded(
        child: state.data.videos.isEmpty
            ? const Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.all(BookletSpace.s4),
                  child: Text(TeacherVideosCopy.empty),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(BookletSpace.s4),
                itemCount: state.data.videos.length,
                itemBuilder: (context, index) => TeacherVideoCard(
                  key: ValueKey('video-${state.data.videos[index].assetId}'),
                  video: state.data.videos[index],
                  busy: state.busy,
                  first: index == 0,
                  last: index == state.data.videos.length - 1,
                ),
              ),
      ),
    ],
  );
}
