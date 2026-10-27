import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/video/video_provider.dart';
import 'package:sat_east_client/features/video/domain/entities/video_playback.dart';
import 'package:sat_east_client/features/video/domain/entities/video_settings.dart';
import 'package:sat_east_client/features/video/domain/repositories/video_repository.dart';
import 'package:sat_east_client/features/video/domain/services/progress_tracker.dart';
import 'package:sat_east_client/features/video/domain/services/video_engine.dart';
import 'package:sat_east_client/features/video/presentation/cubit/video_player_state.dart';

class VideoPlayerCubit extends Cubit<VideoPlayerState> {
  VideoPlayerCubit(
    this._repo,
    this._engineFor, {
    required this.periodic,
    required this.now,
  }) : super(const VideoPlayerLoading());

  final VideoRepository _repo;
  final VideoEngine Function(VideoProvider) _engineFor;
  final Timer Function(Duration, void Function(Timer)) periodic;
  final DateTime Function() now;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  final List<DateTime> _recoveries = [];
  VideoEngine? _engine;
  ProgressTracker? _tracker;
  Timer? _heartbeat;
  Timer? _watchdog;
  DateTime? _lastMovement;
  String? _assetId;
  VideoProvider? _provider;
  int _intervalS = 0;
  double _positionS = 0;
  int _generation = 0;
  bool _closing = false;
  bool _recovering = false;
  Future<void> _saveQueue = Future.value();
  Future<void>? _closingFuture;

  bool get _active => !isClosed && !_closing;
  String? get viewType => _engine?.viewType;

  /// Provider may be omitted on a deep link; the grant identifies the engine.
  Future<void> load(String assetId, [VideoProvider? provider]) async {
    if (!_active) return;
    final generation = ++_generation;
    _stopTimers();
    await _cancelSubscriptions();
    if (!_active || generation != _generation) return;
    await _flush();
    if (!_active || generation != _generation) return;
    final oldEngine = _engine;
    _engine = null;
    await oldEngine?.dispose();
    if (!_active || generation != _generation) return;
    _assetId = assetId;
    _provider = provider;
    _recoveries.clear();
    _recovering = false;
    _tracker = null;
    emit(const VideoPlayerLoading());
    final settings = await _repo.loadSettings();
    if (!_active || generation != _generation) return;
    if (settings case Failure(:final error)) {
      _fail(error.code);
      return;
    }
    final config = (settings as Success<VideoSettings>).value;
    // The repository validates both configured periods at the data boundary.
    _intervalS = config.progressIntervalS;
    final watermarkMoveS = config.watermarkMoveS;
    final result = await _repo.requestPlayback(assetId);
    if (!_active || generation != _generation) return;
    if (result case Failure(:final error)) {
      _fail(error.code);
      return;
    }
    final playback = (result as Success<VideoPlayback>).value;
    final actualProvider = switch (playback) {
      HlsPlayback() => VideoProvider.r2Hls,
      YoutubePlayback() => VideoProvider.youtube,
    };
    final engine = _engineFor(actualProvider);
    _engine = engine;
    _subscribe(engine);
    emit(VideoPlayerLoading(viewType: engine.viewType));
    final attached = await engine.attach(playback);
    if (!_active || generation != _generation) return;
    if (attached case Failure(:final error)) {
      _fail(error.code);
      return;
    }
    _tracker = ProgressTracker(intervalS: _intervalS)
      ..onPosition(playback.resumeS.toDouble());
    _lastMovement = now();
    _positionS = playback.resumeS.toDouble();
    emit(
      VideoPlayerReady(
        playback: playback,
        status: EngineStatus.paused,
        positionS: playback.resumeS.toDouble(),
        durationS: engine.durationS,
        rate: 1,
        fullscreen: false,
        done: false,
        watermarkMoveS: watermarkMoveS,
      ),
    );
    _heartbeat = periodic(Duration(seconds: _intervalS), (_) {
      if (_active) unawaited(_flush());
    });
    _watchdog = periodic(const Duration(seconds: 1), (_) {
      final current = state;
      if (_active &&
          !_recovering &&
          current is VideoPlayerReady &&
          (current.status == EngineStatus.playing ||
              current.status == EngineStatus.buffering) &&
          _lastMovement != null &&
          now().difference(_lastMovement!) >= const Duration(seconds: 10)) {
        unawaited(_recover());
      }
    });
  }

  void _subscribe(VideoEngine engine) {
    _subscriptions
      ..add(engine.position.listen(_onPosition))
      ..add(engine.status.listen(_onStatus))
      ..add(engine.fatalErrors.listen((_) => unawaited(_recover())));
    if (engine case final FullscreenVideoEngine fullscreenEngine) {
      _subscriptions.add(
        fullscreenEngine.fullscreenChanges.listen((full) {
          if (state case final VideoPlayerReady ready when _active) {
            emit(ready.copyWith(fullscreen: full));
          }
        }),
      );
    }
  }

  void _onPosition(double position) {
    if (!_active || !position.isFinite || position < 0) return;
    final current = state;
    if (current is! VideoPlayerReady || _recovering) return;
    if (position != current.positionS) _lastMovement = now();
    _positionS = position;
    _tracker?.onPosition(position);
    emit(current.copyWith(positionS: position, durationS: _engine?.durationS));
  }

  void _onStatus(EngineStatus status) {
    if (!_active || _recovering) return;
    final current = state;
    if (current is! VideoPlayerReady) return;
    if (status == EngineStatus.playing && current.status != status) {
      _lastMovement = now();
    }
    emit(current.copyWith(status: status, durationS: _engine?.durationS));
    if (status == EngineStatus.paused || status == EngineStatus.ended) {
      unawaited(_flush());
    }
  }

  Future<void> togglePlay() async {
    final current = state;
    if (!_active || current is! VideoPlayerReady || _recovering) return;
    if (current.status == EngineStatus.playing ||
        current.status == EngineStatus.buffering) {
      _engine?.pause();
      await _flush();
      if (!_active) return;
    } else {
      _engine?.play();
    }
  }

  void seek(double s) {
    final current = state;
    if (!_active ||
        current is! VideoPlayerReady ||
        !s.isFinite ||
        _recovering) {
      return;
    }
    final target = s.clamp(0.0, current.durationS ?? double.infinity);
    unawaited(_flush());
    // Reset even for a small seek, which a position delta cannot identify.
    _tracker = ProgressTracker(intervalS: _intervalS)..onPosition(target);
    _lastMovement = now();
    _positionS = target;
    _engine?.seek(target);
    emit(current.copyWith(positionS: target));
  }

  void setRate(double rate) {
    final current = state;
    if (!_active ||
        current is! VideoPlayerReady ||
        !const [1.0, 1.25, 1.5].contains(rate)) {
      return;
    }
    _engine?.setRate(rate);
    emit(current.copyWith(rate: rate));
  }

  Future<void> toggleFullscreen() async {
    final current = state;
    if (!_active || current is! VideoPlayerReady) return;
    try {
      if (current.fullscreen) {
        await _engine?.exitFullscreen();
      } else {
        await _engine?.requestFullscreen();
      }
      if (!_active) return;
      if (state case final VideoPlayerReady ready) {
        emit(ready.copyWith(fullscreen: !current.fullscreen));
      }
    } on Object {
      if (_active) _fail(ErrorCodes.internal);
    }
  }

  Future<void> retry() async {
    final id = _assetId;
    if (id != null && _active) await load(id, _provider);
  }

  Future<void> _flush() {
    final tracker = _tracker;
    final id = _assetId;
    if (isClosed || tracker == null || id == null || !tracker.hasPending) {
      return _saveQueue;
    }
    final spans = tracker.takeSpans();
    final position = _positionS.floor();
    final generation = _generation;
    return _saveQueue = _saveQueue.then((_) async {
      for (final span in spans) {
        if (isClosed) return;
        final result = await _repo.saveProgress(id, span, position);
        if (!_active || generation != _generation) {
          if (result case Failure(:final error)) {
            addError(AppError(error.code), StackTrace.current);
          }
          continue;
        }
        switch (result) {
          case Success(:final value):
            if (state case final VideoPlayerReady ready) {
              emit(ready.copyWith(done: value.done));
            }
          case Failure(:final error):
            _fail(error.code);
            return;
        }
      }
    });
  }

  Future<void> _recover() async {
    final current = state;
    final id = _assetId;
    if (!_active || _recovering || current is! VideoPlayerReady || id == null) {
      return;
    }
    final recoveryTime = now();
    _recoveries.removeWhere(
      (t) => recoveryTime.difference(t) >= const Duration(minutes: 1),
    );
    if (_recoveries.length >= 3) {
      _fail(ErrorCodes.internal);
      return;
    }
    _recoveries.add(recoveryTime);
    _recovering = true;
    final generation = _generation;
    await _flush();
    if (!_active || generation != _generation) return;
    if (state is! VideoPlayerReady) {
      _recovering = false;
      return;
    }
    final result = await _repo.requestPlayback(id);
    if (!_active || generation != _generation) return;
    if (result case Failure(:final error)) {
      _fail(error.code);
      return;
    }
    final playback = _withResume(
      (result as Success<VideoPlayback>).value,
      current.positionS.floor(),
    );
    final attached = await _engine!.attach(playback);
    if (!_active || generation != _generation) return;
    if (attached case Failure(:final error)) {
      _fail(error.code);
      return;
    }
    _tracker = ProgressTracker(intervalS: _intervalS)
      ..onPosition(current.positionS);
    _lastMovement = now();
    _recovering = false;
    final latest = state;
    if (latest is! VideoPlayerReady) return;
    _engine!.setRate(latest.rate);
    emit(
      latest.copyWith(
        playback: playback,
        status: EngineStatus.paused,
        durationS: _engine!.durationS,
      ),
    );
    if (current.status == EngineStatus.playing ||
        current.status == EngineStatus.buffering) {
      _engine!.play();
    }
  }

  void _fail(String code) {
    if (!_active) return;
    _stopTimers();
    _recovering = false;
    emit(VideoPlayerError(code));
    _engine?.pause();
  }

  void _stopTimers() {
    _heartbeat?.cancel();
    _watchdog?.cancel();
  }

  Future<void> _cancelSubscriptions() async {
    final subscriptions = _subscriptions.toList();
    _subscriptions.clear();
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
  }

  @override
  Future<void> close() async {
    if (_closing) {
      await _closingFuture;
      return;
    }
    _closing = true;
    _closingFuture = _closeResources();
    await _closingFuture;
    await super.close();
  }

  Future<void> _closeResources() async {
    _stopTimers();
    _engine?.pause();
    await _cancelSubscriptions();
    if (isClosed) return;
    await _flush();
    if (isClosed) return;
    final engine = _engine;
    if (engine != null) {
      try {
        await engine.exitFullscreen();
      } on Object {
        addError(const AppError(ErrorCodes.internal), StackTrace.current);
      }
      if (isClosed) return;
      await engine.dispose();
      if (isClosed) return;
    }
  }
}

VideoPlayback _withResume(VideoPlayback playback, int resumeS) =>
    switch (playback) {
      HlsPlayback() => HlsPlayback(
        hlsUrl: playback.hlsUrl,
        expiresAt: playback.expiresAt,
        watermarkName: playback.watermarkName,
        watermarkShortId: playback.watermarkShortId,
        resumeS: resumeS,
      ),
      YoutubePlayback() => YoutubePlayback(
        youtubeId: playback.youtubeId,
        resumeS: resumeS,
      ),
    };
