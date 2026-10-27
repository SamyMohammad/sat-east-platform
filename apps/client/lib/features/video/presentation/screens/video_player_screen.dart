import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/video/domain/entities/video_playback.dart';
import 'package:sat_east_client/features/video/presentation/cubit/video_player_cubit.dart';
import 'package:sat_east_client/features/video/presentation/cubit/video_player_state.dart';
import 'package:sat_east_client/features/video/presentation/video_copy.dart';
import 'package:sat_east_client/features/video/presentation/widgets/moving_watermark.dart';
import 'package:sat_east_client/features/video/presentation/widgets/video_controls.dart';
import 'package:sat_east_client/shared/widgets/app_skeleton.dart';
import 'package:sat_east_client/shared/widgets/error_retry.dart';

/// Replaces only the platform view in VM widget tests.
typedef VideoSurfaceBuilder = Widget Function(BuildContext, String);

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({
    required this.topicId,
    required this.assetId,
    this.surfaceBuilder,
    this.onPrepareExit,
    super.key,
  });
  final String topicId;
  final String assetId;
  final VideoSurfaceBuilder? surfaceBuilder;
  final ValueChanged<Future<void> Function()>? onPrepareExit;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final VideoPlayerCubit _cubit;
  final _random = Random();
  @override
  void initState() {
    super.initState();
    _cubit = getIt<VideoPlayerCubit>();
    widget.onPrepareExit?.call(_cubit.close);
    unawaited(_cubit.load(widget.assetId));
  }

  @override
  void didUpdateWidget(VideoPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.assetId != oldWidget.assetId) {
      unawaited(_cubit.load(widget.assetId));
    }
  }

  @override
  void dispose() {
    unawaited(_cubit.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _cubit,
    child: VideoPlayerView(
      topicId: widget.topicId,
      random: _random,
      surfaceBuilder: widget.surfaceBuilder,
    ),
  );
}

class VideoPlayerView extends StatefulWidget {
  const VideoPlayerView({
    required this.topicId,
    required this.random,
    this.surfaceBuilder,
    super.key,
  });
  final String topicId;
  final Random random;
  final VideoSurfaceBuilder? surfaceBuilder;
  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  final _portal = OverlayPortalController();
  final GlobalKey<State<StatefulWidget>> _surfaceKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncFullscreen(context.read<VideoPlayerCubit>().state);
    });
  }

  void _syncFullscreen(VideoPlayerState state) {
    if (state is VideoPlayerReady && state.fullscreen) {
      _portal.show();
    } else {
      _portal.hide();
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<VideoPlayerCubit, VideoPlayerState>(
        listener: (_, state) => _syncFullscreen(state),
        listenWhen: (previous, next) =>
            (previous is VideoPlayerReady && previous.fullscreen) !=
            (next is VideoPlayerReady && next.fullscreen),
        child: OverlayPortal(
          overlayLocation: OverlayChildLocation.rootOverlay,
          controller: _portal,
          overlayChildBuilder: (context) => Positioned.fill(
            child: Material(
              color: context.appColors.examBar,
              child: SafeArea(child: _player(context, fullscreen: true)),
            ),
          ),
          child: Scaffold(
            appBar: AppBar(
              title: const Text(VideoCopy.title),
              leading: BackButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(AppRoutes.topic(widget.topicId));
                  }
                },
              ),
            ),
            body: BlocBuilder<VideoPlayerCubit, VideoPlayerState>(
              buildWhen: (previous, next) =>
                  previous.runtimeType != next.runtimeType ||
                  previous is VideoPlayerLoading ||
                  (previous is VideoPlayerReady &&
                      next is VideoPlayerReady &&
                      (previous.fullscreen != next.fullscreen ||
                          previous.playback != next.playback)),
              builder: (context, state) => switch (state) {
                VideoPlayerError(:final code) => SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpace.s4),
                  child: ErrorRetry(
                    title: VideoCopy.error(code),
                    message: '',
                    onRetry: () =>
                        unawaited(context.read<VideoPlayerCubit>().retry()),
                  ),
                ),
                VideoPlayerReady(fullscreen: true) => const SizedBox.expand(),
                VideoPlayerReady() ||
                VideoPlayerLoading() => _player(context, fullscreen: false),
              },
            ),
          ),
        ),
      );

  Widget _player(BuildContext context, {required bool fullscreen}) {
    final cubit = context.read<VideoPlayerCubit>();
    final state = cubit.state;
    final loading = state is VideoPlayerLoading;
    final viewType = state is VideoPlayerLoading
        ? state.viewType
        : cubit.viewType;
    final video = ColoredBox(
      color: context.appColors.examBar,
      child: Stack(
        key: _surfaceKey,
        fit: StackFit.expand,
        children: [
          if (widget.surfaceBuilder != null)
            widget.surfaceBuilder!(context, viewType ?? '')
          else if (viewType != null)
            HtmlElementView(viewType: viewType),
          if (state case VideoPlayerReady(:final HlsPlayback playback))
            MovingWatermark(
              text: playback.watermarkText,
              period: Duration(seconds: state.watermarkMoveS),
              random: widget.random,
            ),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(AppSpace.s4),
              child: AppSkeleton(label: VideoCopy.loading),
            ),
        ],
      ),
    );
    return Column(
      children: [
        Expanded(
          child: fullscreen
              ? video
              : Center(
                  child: AspectRatio(aspectRatio: 16 / 9, child: video),
                ),
        ),
        if (!loading)
          BlocBuilder<VideoPlayerCubit, VideoPlayerState>(
            builder: (context, state) => state is! VideoPlayerReady
                ? const SizedBox.shrink()
                : VideoControls(
                    status: state.status,
                    positionS: state.positionS,
                    durationS: state.durationS,
                    rate: state.rate,
                    fullscreen: state.fullscreen,
                    onTogglePlay: () => unawaited(cubit.togglePlay()),
                    onSeek: cubit.seek,
                    onSetRate: cubit.setRate,
                    onToggleFullscreen: () =>
                        unawaited(cubit.toggleFullscreen()),
                  ),
          ),
      ],
    );
  }
}
