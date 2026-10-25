import 'dart:async';
import 'dart:js_interop';

import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/video/data/services/video_script_loader.dart';
import 'package:sat_east_client/features/video/data/services/web_video_engine.dart';
import 'package:sat_east_client/features/video/domain/entities/video_playback.dart';
import 'package:sat_east_client/features/video/domain/services/video_engine.dart';
import 'package:web/web.dart' as web;

@JS('YT')
external JSObject? get _youtube;
@JS('YT.Player')
external JSFunction? get _playerConstructor;
bool get _apiReady => _youtube != null && _playerConstructor != null;
@JS('onYouTubeIframeAPIReady')
external set _onApiReady(JSFunction value);

@JS('YT.Player')
extension type _Player._(JSObject _) implements JSObject {
  external factory _Player(web.HTMLElement host, JSObject options);
  external double getCurrentTime();
  external double getDuration();
  external void playVideo();
  external void pauseVideo();
  // JavaScript requires a positional flag.
  // ignore: avoid_positional_boolean_parameters
  external void seekTo(double seconds, bool allowSeekAhead);
  external void setPlaybackRate(double rate);
  external void destroy();
}

extension type _PlayerEvent(JSObject _) implements JSObject {
  external int get data;
}

Future<void>? _apiLoad;
Future<void> _loadApi() => _apiLoad ??= _loadApiOnce();
Future<void> _loadApiOnce() async {
  if (_apiReady) return;
  final ready = Completer<void>();
  void onReady() {
    if (!ready.isCompleted) ready.complete();
  }

  _onApiReady = onReady.toJS;
  try {
    await loadVideoScript('https://www.youtube.com/iframe_api');
    if (_apiReady) onReady();
    await ready.future.timeout(const Duration(seconds: 20));
  } on Object {
    _apiLoad = null;
    rethrow;
  }
}

class YoutubeWebEngine extends WebVideoEngine {
  YoutubeWebEngine() : super('youtube-video', web.HTMLDivElement()) {
    _poll = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_playing) emitPosition(_player?.getCurrentTime() ?? 0);
    });
  }

  _Player? _player;
  Timer? _poll;
  bool _playing = false;
  int _generation = 0;
  Completer<void>? _ready;

  @override
  double? get durationS {
    final value = _player?.getDuration();
    return value != null && value.isFinite && value > 0 ? value : null;
  }

  @override
  Future<Result<void>> attach(VideoPlayback playback) async {
    if (disposed || playback is! YoutubePlayback) {
      return const Failure(AppError(ErrorCodes.internal));
    }
    final generation = ++_generation;
    emitStatus(EngineStatus.loading);
    try {
      await _loadApi();
      if (disposed || generation != _generation) {
        return const Failure(AppError(ErrorCodes.internal));
      }
      _playing = false;
      _player?.destroy();
      // YouTube replaces its host. Keep our registered platform-view root.
      final host = web.HTMLDivElement();
      element.replaceChildren(host);
      final ready = Completer<void>();
      _ready = ready;
      void onReady(JSObject _) {
        if (!ready.isCompleted) ready.complete();
      }

      void onError(JSObject _) {
        if (!ready.isCompleted) {
          ready.completeError(StateError('YouTube unavailable'));
        } else if (generation == _generation) {
          emitFatal();
        }
      }

      void onState(_PlayerEvent event) {
        if (disposed || generation != _generation) return;
        _playing = event.data == 1;
        final status = switch (event.data) {
          0 => EngineStatus.ended,
          1 => EngineStatus.playing,
          2 => EngineStatus.paused,
          3 => EngineStatus.buffering,
          _ => EngineStatus.idle,
        };
        if (status == EngineStatus.paused || status == EngineStatus.ended) {
          emitPosition(_player?.getCurrentTime() ?? 0);
        }
        emitStatus(status);
      }

      final options =
          {
                'width': '100%',
                'height': '100%',
                'videoId': playback.youtubeId,
                'host': 'https://www.youtube-nocookie.com',
                'playerVars': {
                  'controls': 0,
                  'disablekb': 1,
                  'modestbranding': 1,
                  'rel': 0,
                  'playsinline': 1,
                  'start': playback.resumeS,
                  'origin': web.window.location.origin,
                },
                'events': {
                  'onReady': onReady.toJS,
                  'onError': onError.toJS,
                  'onStateChange': onState.toJS,
                },
              }.jsify()!
              as JSObject;
      _player = _Player(host, options);
      await ready.future.timeout(const Duration(seconds: 20));
      if (disposed || generation != _generation) {
        return const Failure(AppError(ErrorCodes.internal));
      }
      _player!.seekTo(playback.resumeS.toDouble(), true);
      emitStatus(EngineStatus.paused);
      return const Success(null);
    } on Object {
      return const Failure(AppError(ErrorCodes.internal));
    }
  }

  @override
  void play() => _player?.playVideo();
  @override
  void pause() => _player?.pauseVideo();
  @override
  void seek(double s) => _player?.seekTo(s.clamp(0.0, durationS ?? s), true);
  @override
  void setRate(double r) => _player?.setPlaybackRate(r);

  @override
  Future<void> dispose() async {
    if (disposed) return;
    ++_generation;
    _poll?.cancel();
    final ready = _ready;
    if (ready != null && !ready.isCompleted) ready.complete();
    _player?.destroy();
    await disposeBase();
  }
}
