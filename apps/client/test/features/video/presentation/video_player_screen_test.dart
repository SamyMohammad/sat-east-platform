import 'dart:async';
import 'dart:math';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/video/domain/entities/video_playback.dart';
import 'package:sat_east_client/features/video/domain/services/video_engine.dart';
import 'package:sat_east_client/features/video/presentation/cubit/video_player_cubit.dart';
import 'package:sat_east_client/features/video/presentation/cubit/video_player_state.dart';
import 'package:sat_east_client/features/video/presentation/screens/video_player_screen.dart';
import 'package:sat_east_client/features/video/presentation/widgets/moving_watermark.dart';

class _Cubit extends MockCubit<VideoPlayerState> implements VideoPlayerCubit {}

void main() {
  testWidgets('SEC-01: fullscreen transition preserves the watermark', (
    tester,
  ) async {
    final cubit = _Cubit();
    final states = StreamController<VideoPlayerState>();
    final ready = VideoPlayerReady(
      playback: HlsPlayback(
        hlsUrl: 'https://example.test/master.m3u8',
        expiresAt: DateTime.utc(2026, 10, 26),
        watermarkName: 'Sara Ali',
        watermarkShortId: '3FA2C1',
        resumeS: 0,
      ),
      status: EngineStatus.paused,
      positionS: 0,
      durationS: 600,
      rate: 1,
      fullscreen: false,
      done: false,
      watermarkMoveS: 7,
    );
    whenListen(cubit, states.stream, initialState: ready);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: BlocProvider<VideoPlayerCubit>.value(
          value: cubit,
          child: VideoPlayerView(
            topicId: 't',
            random: Random(1),
            surfaceBuilder: (_, _) => const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pump();
    states.add(ready.copyWith(fullscreen: true));
    await tester.pump();
    await tester.pump();
    expect(find.byType(MovingWatermark), findsOneWidget);
    expect(find.text('Sara Ali \u00b7 3FA2C1'), findsOneWidget);
    states.add(ready);
    await tester.pump();
    await tester.pump();
    expect(find.byType(MovingWatermark), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await states.close();
  });
  for (final fullscreen in [false, true]) {
    testWidgets(
      'SEC-01: in fullscreen=$fullscreen state '
      'the watermark is still in the tree',
      (tester) async {
        final cubit = _Cubit();
        final playback = HlsPlayback(
          hlsUrl: 'https://example.test/master.m3u8',
          expiresAt: DateTime.utc(2026, 10, 26),
          watermarkName: 'Sara Ali',
          watermarkShortId: '3FA2C1',
          resumeS: 0,
        );
        whenListen(
          cubit,
          const Stream<VideoPlayerState>.empty(),
          initialState: VideoPlayerReady(
            playback: playback,
            status: EngineStatus.paused,
            positionS: 0,
            durationS: 600,
            rate: 1,
            fullscreen: fullscreen,
            done: false,
            watermarkMoveS: 7,
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: BlocProvider<VideoPlayerCubit>.value(
              value: cubit,
              child: VideoPlayerView(
                topicId: 't',
                random: Random(1),
                surfaceBuilder: (_, _) => const SizedBox.expand(),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(MovingWatermark), findsOneWidget);
        expect(find.text('Sara Ali \u00b7 3FA2C1'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('SEC-01: YouTube has no watermark', (tester) async {
    final cubit = _Cubit();
    whenListen(
      cubit,
      const Stream<VideoPlayerState>.empty(),
      initialState: const VideoPlayerReady(
        playback: YoutubePlayback(youtubeId: 'dQw4w9WgXcQ', resumeS: 0),
        status: EngineStatus.paused,
        positionS: 0,
        durationS: 600,
        rate: 1,
        fullscreen: false,
        done: false,
        watermarkMoveS: 7,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: BlocProvider<VideoPlayerCubit>.value(
          value: cubit,
          child: VideoPlayerView(
            topicId: 't',
            random: Random(1),
            surfaceBuilder: (_, _) => const SizedBox.expand(),
          ),
        ),
      ),
    );
    expect(find.byType(MovingWatermark), findsNothing);
  });
}
