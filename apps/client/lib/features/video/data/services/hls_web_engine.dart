import 'dart:async';
import 'dart:js_interop';

import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/video/data/services/video_script_loader.dart';
import 'package:sat_east_client/features/video/data/services/web_video_engine.dart';
import 'package:sat_east_client/features/video/domain/entities/video_playback.dart';
import 'package:sat_east_client/features/video/domain/services/video_engine.dart';
import 'package:web/web.dart' as web;

@JS('Hls')
extension type _Hls._(JSObject _) implements JSObject {
  external factory _Hls();
  external static bool isSupported();
  external void loadSource(String url);
  external void attachMedia(web.HTMLVideoElement video);
  external void on(String event, JSFunction callback);
  external void destroy();
}

extension type _HlsError(JSObject _) implements JSObject {
  external bool get fatal;
}

class HlsWebEngine extends WebVideoEngine {
  HlsWebEngine() : super('hls-video', web.HTMLVideoElement()) {
    _video
      ..controls = false
      ..playsInline = true
      ..disablePictureInPicture = true
      ..setAttribute('controlsList', 'nodownload noremoteplayback')
      ..setAttribute('disableRemotePlayback', '')
      ..oncontextmenu = ((web.Event event) => event.preventDefault()).toJS
      ..onplaying = ((web.Event _) => emitStatus(EngineStatus.playing)).toJS
      ..onpause = ((web.Event _) => emitStatus(EngineStatus.paused)).toJS
      ..onwaiting = ((web.Event _) => emitStatus(EngineStatus.buffering)).toJS
      ..onended = ((web.Event _) {
        emitPosition(_video.currentTime);
        emitStatus(EngineStatus.ended);
      }).toJS
      ..onerror = ((web.Event _) => _handleFatal()).toJS;
    _poll = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!_video.paused && !_video.seeking && _video.readyState >= 2) {
        emitPosition(_video.currentTime);
      }
    });
  }

  web.HTMLVideoElement get _video => element as web.HTMLVideoElement;
  _Hls? _hls;
  Timer? _poll;
  int _generation = 0;
  Completer<void>? _metadata;

  @override
  double? get durationS {
    final duration = _video.duration;
    return duration.isFinite && duration > 0 ? duration : null;
  }

  @override
  Future<Result<void>> attach(VideoPlayback playback) async {
    if (disposed || playback is! HlsPlayback) {
      return const Failure(AppError(ErrorCodes.internal));
    }
    final generation = ++_generation;
    emitStatus(EngineStatus.loading);
    try {
      await loadVideoScript('vendor/hls-1.7.3.min.js');
      if (disposed || generation != _generation) {
        return const Failure(AppError(ErrorCodes.internal));
      }
      _hls?.destroy();
      _hls = null;
      final ready = Completer<void>();
      _metadata = ready;
      _video.onloadedmetadata = ((web.Event _) {
        if (!ready.isCompleted) ready.complete();
      }).toJS;
      if (_Hls.isSupported()) {
        final hls = _Hls();
        _hls = hls;
        hls
          ..on(
            'hlsError',
            ((JSString _, _HlsError error) {
              if (generation == _generation && error.fatal) _handleFatal();
            }).toJS,
          )
          ..loadSource(playback.hlsUrl)
          ..attachMedia(_video);
      } else if (_video.canPlayType('application/vnd.apple.mpegurl') != '') {
        _video
          ..src = playback.hlsUrl
          ..load();
      } else {
        return const Failure(AppError(ErrorCodes.unsupported));
      }
      await ready.future.timeout(const Duration(seconds: 20));
      if (disposed || generation != _generation) {
        return const Failure(AppError(ErrorCodes.internal));
      }
      seek(playback.resumeS.toDouble());
      emitStatus(EngineStatus.paused);
      return const Success(null);
    } on Object {
      return const Failure(AppError(ErrorCodes.internal));
    }
  }

  void _handleFatal() {
    final metadata = _metadata;
    if (metadata != null && !metadata.isCompleted) {
      metadata.completeError(StateError('Video unavailable'));
    } else {
      emitFatal();
    }
  }

  @override
  void play() => unawaited(_play());
  Future<void> _play() async {
    try {
      await _video.play().toDart;
    } on Object {
      emitStatus(EngineStatus.paused);
    }
  }

  @override
  void pause() {
    _video.pause();
    emitPosition(_video.currentTime);
  }

  @override
  void seek(double s) {
    _video.currentTime = s.clamp(0.0, durationS ?? s);
  }

  @override
  void setRate(double r) => _video.playbackRate = r;

  @override
  Future<void> dispose() async {
    if (disposed) return;
    ++_generation;
    _poll?.cancel();
    final metadata = _metadata;
    if (metadata != null && !metadata.isCompleted) metadata.complete();
    _video
      ..pause()
      ..onloadedmetadata = null
      ..onplaying = null
      ..onpause = null
      ..onwaiting = null
      ..onended = null
      ..onerror = null
      ..oncontextmenu = null;
    _hls?.destroy();
    _video
      ..removeAttribute('src')
      ..load();
    await disposeBase();
  }
}
