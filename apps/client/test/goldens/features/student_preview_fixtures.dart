// Keep the SDK / third-party / project import groups required by AGENTS.md.
// ignore_for_file: directives_ordering

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/attempt_review/data/models/attempt_review_model.dart';
import 'package:sat_east_client/features/attempt_review/presentation/cubit/attempt_review_cubit.dart';
import 'package:sat_east_client/features/attempt_review/presentation/cubit/attempt_review_state.dart';
import 'package:sat_east_client/features/attempt_review/presentation/screens/attempt_review_screen.dart';
import 'package:sat_east_client/features/homework/presentation/cubit/homework_cubit.dart';
import 'package:sat_east_client/features/homework/presentation/cubit/homework_state.dart';
import 'package:sat_east_client/features/homework/presentation/screens/homework_screen.dart';
import 'package:sat_east_client/features/notes/presentation/cubit/notes_viewer_cubit.dart';
import 'package:sat_east_client/features/notes/presentation/cubit/notes_viewer_state.dart';
import 'package:sat_east_client/features/notes/presentation/screens/notes_viewer_screen.dart';
import 'package:sat_east_client/features/video/domain/entities/video_playback.dart';
import 'package:sat_east_client/features/video/domain/services/video_engine.dart';
import 'package:sat_east_client/features/video/presentation/cubit/video_player_cubit.dart';
import 'package:sat_east_client/features/video/presentation/cubit/video_player_state.dart';
import 'package:sat_east_client/features/video/presentation/screens/video_player_screen.dart';

import '../../features/attempt_review/review_fixture.dart';
import '../../features/homework/homework_fixture.dart';
import 'student_notes_preview.dart';

class _Homework extends MockCubit<HomeworkState> implements HomeworkCubit {}

class _Review extends MockCubit<AttemptReviewState>
    implements AttemptReviewCubit {}

class _Video extends MockCubit<VideoPlayerState> implements VideoPlayerCubit {}

class _Notes extends MockCubit<NotesViewerState> implements NotesViewerCubit {}

Widget studentPreview(String screen, {bool failed = false}) {
  switch (screen) {
    case 'homework':
      final cubit = _Homework();
      whenListen(
        cubit,
        const Stream<HomeworkState>.empty(),
        initialState: failed
            ? const HomeworkFailed(AppError('network'))
            : const HomeworkRunning(
                session: homeworkSession,
                answers: {'q1': 'B'},
                marked: {'q1'},
              ),
      );
      addTearDown(cubit.close);
      return Scaffold(
        body: BlocProvider<HomeworkCubit>.value(
          value: cubit,
          child: const HomeworkView(topicId: 't1'),
        ),
      );
    case 'attempt_review':
      final cubit = _Review();
      whenListen(
        cubit,
        const Stream<AttemptReviewState>.empty(),
        initialState: failed
            ? const AttemptReviewFailed(AppError('network'))
            : AttemptReviewLoaded(
                attemptReviewFromJson(reviewPayload()),
              ),
      );
      addTearDown(cubit.close);
      return Scaffold(
        body: BlocProvider<AttemptReviewCubit>.value(
          value: cubit,
          child: const AttemptReviewView(attemptId: 'hw1'),
        ),
      );
    case 'video_player':
      final cubit = _Video();
      whenListen(
        cubit,
        const Stream<VideoPlayerState>.empty(),
        initialState: failed
            ? const VideoPlayerError('network')
            : VideoPlayerReady(
                playback: HlsPlayback(
                  hlsUrl: 'https://example.test/video.m3u8',
                  expiresAt: DateTime.utc(2027),
                  watermarkName: 'Sara Ali',
                  watermarkShortId: '3FA2C1',
                  resumeS: 0,
                ),
                status: EngineStatus.paused,
                positionS: 65,
                durationS: 600,
                rate: 1,
                fullscreen: false,
                done: false,
                watermarkMoveS: 7,
              ),
      );
      addTearDown(cubit.close);
      return BlocProvider<VideoPlayerCubit>.value(
        value: cubit,
        child: VideoPlayerView(
          topicId: 't1',
          random: Random(1),
          surfaceBuilder: (_, _) => const SizedBox.expand(),
        ),
      );
    case 'notes_viewer':
      final cubit = _Notes();
      whenListen(
        cubit,
        const Stream<NotesViewerState>.empty(),
        initialState: failed
            ? const NotesViewerFailed(AppError('network'))
            : NotesViewerReady(
                bytes: Uint8List.fromList([1]),
                watermark: 'Sara \u00b7 sara \u00b7 2026-10-27',
              ),
      );
      when(() => cubit.load('t1', 'a1')).thenAnswer((_) async {});
      getIt.registerFactory<NotesViewerCubit>(() => cubit);
      addTearDown(() => getIt.unregister<NotesViewerCubit>());
      return const NotesViewerScreen(
        topicId: 't1',
        assetId: 'a1',
        documentBuilder: studentNotesPreview,
      );
    default:
      throw ArgumentError.value(screen);
  }
}
