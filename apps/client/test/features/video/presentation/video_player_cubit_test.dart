import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/video/video_provider.dart';
import 'package:sat_east_client/features/video/domain/entities/video_playback.dart';
import 'package:sat_east_client/features/video/domain/entities/video_settings.dart';
import 'package:sat_east_client/features/video/domain/entities/watched_span.dart';
import 'package:sat_east_client/features/video/domain/repositories/video_repository.dart';
import 'package:sat_east_client/features/video/domain/services/video_engine.dart';
import 'package:sat_east_client/features/video/presentation/cubit/video_player_cubit.dart';
import 'package:sat_east_client/features/video/presentation/cubit/video_player_state.dart';

class _Timer implements Timer {
  _Timer(this.callback);
  final void Function(Timer) callback;
  @override
  bool isActive = true;
  @override
  int tick = 0;
  void fire() {
    if (isActive) {
      tick++;
      callback(this);
    }
  }

  @override
  void cancel() => isActive = false;
}

class _Engine implements VideoEngine, FullscreenVideoEngine {
  final StreamController<double> positions = StreamController<double>.broadcast(
    sync: true,
  );
  final StreamController<EngineStatus> statuses =
      StreamController<EngineStatus>.broadcast(sync: true);
  final StreamController<AppError> errors =
      StreamController<AppError>.broadcast(sync: true);
  final StreamController<bool> fullscreens = StreamController<bool>.broadcast(
    sync: true,
  );
  final attached = <VideoPlayback>[];
  final rates = <double>[];
  final seeks = <double>[];
  int plays = 0;
  int pauses = 0;
  int disposals = 0;
  bool fullscreen = false;
  bool fullscreenFails = false;
  Result<void> attachResult = const Success(null);
  Completer<Result<void>>? pendingAttach;
  @override
  String get viewType => 'fake-video';
  @override
  double? get durationS => 600;
  @override
  Stream<double> get position => positions.stream;
  @override
  Stream<EngineStatus> get status => statuses.stream;
  @override
  Stream<AppError> get fatalErrors => errors.stream;
  @override
  Stream<bool> get fullscreenChanges => fullscreens.stream;
  @override
  Future<Result<void>> attach(VideoPlayback playback) async {
    attached.add(playback);
    return pendingAttach?.future ?? attachResult;
  }

  @override
  void play() => plays++;
  @override
  void pause() => pauses++;
  @override
  void seek(double s) => seeks.add(s);
  @override
  void setRate(double r) => rates.add(r);
  @override
  Future<void> requestFullscreen() async {
    if (fullscreenFails) throw StateError('Fullscreen refused');
    fullscreen = true;
  }

  @override
  Future<void> exitFullscreen() async => fullscreen = false;
  @override
  Future<void> dispose() async {
    disposals++;
  }

  Future<void> disposeStreams() async {
    await positions.close();
    await statuses.close();
    await errors.close();
    await fullscreens.close();
  }
}

class _Repo implements VideoRepository {
  int requests = 0;
  final saves = <(String, WatchedSpan, int)>[];
  Result<VideoPlayback> playback = const Success(
    YoutubePlayback(youtubeId: 'dQw4w9WgXcQ', resumeS: 12),
  );
  Result<VideoSettings> settings = const Success(
    VideoSettings(progressIntervalS: 15, watermarkMoveS: 7),
  );
  Result<({int pct, bool done})> progress = const Success(
    (pct: 80, done: true),
  );
  Completer<Result<VideoPlayback>>? pendingPlayback;
  Completer<Result<({int pct, bool done})>>? pendingSave;
  @override
  Future<Result<VideoPlayback>> requestPlayback(String assetId) async {
    requests++;
    return pendingPlayback?.future ?? playback;
  }

  @override
  Future<Result<VideoSettings>> loadSettings() async => settings;
  @override
  Future<Result<({int pct, bool done})>> saveProgress(
    String assetId,
    WatchedSpan span,
    int positionS,
  ) async {
    saves.add((assetId, span, positionS));
    return pendingSave?.future ?? progress;
  }
}

Future<void> _drain() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.value();
  }
}

void main() {
  late _Repo repo;
  late _Engine engine;
  late VideoPlayerCubit cubit;
  late List<_Timer> timers;
  late DateTime now;
  setUp(() {
    repo = _Repo();
    engine = _Engine();
    timers = [];
    now = DateTime.utc(2026, 10, 25);
    Timer periodic(Duration _, void Function(Timer) callback) {
      final timer = _Timer(callback);
      timers.add(timer);
      return timer;
    }

    cubit = VideoPlayerCubit(
      repo,
      (_) => engine,
      periodic: periodic,
      now: () => now,
    );
  });
  tearDown(() async {
    await cubit.close();
    await engine.disposeStreams();
  });
  Future<void> load() => cubit.load('v', VideoProvider.youtube);
  void advance() {
    for (var s = 12; s <= 26; s++) {
      engine.positions.add(s.toDouble());
    }
  }

  void tick() {
    for (final timer in timers.toList()) {
      timer.fire();
    }
  }

  test('LRN-02: load passes resume to attach and settings to Ready', () async {
    final states = <VideoPlayerState>[];
    final subscription = cubit.stream.listen(states.add);
    await load();
    expect(engine.attached.single.resumeS, 12);
    final ready = cubit.state as VideoPlayerReady;
    expect(ready.positionS, 12);
    expect(ready.watermarkMoveS, 7);
    expect(states.whereType<VideoPlayerLoading>(), isNotEmpty);
    expect(states.last, isA<VideoPlayerReady>());
    await subscription.cancel();
  });
  test('LRN-02: repository error is visible and retry loads again', () async {
    repo.playback = const Failure(AppError('video_needed'));
    await load();
    expect((cubit.state as VideoPlayerError).code, 'video_needed');
    repo.playback = const Success(
      YoutubePlayback(youtubeId: 'dQw4w9WgXcQ', resumeS: 0),
    );
    await cubit.retry();
    expect(cubit.state, isA<VideoPlayerReady>());
  });
  test('LRN-02: settings failure stops before attaching', () async {
    repo.settings = const Failure(AppError('internal'));
    await load();
    expect((cubit.state as VideoPlayerError).code, 'internal');
    expect(engine.attached, isEmpty);
  });
  test('LRN-02: unsupported attach returns an error', () async {
    engine.attachResult = const Failure(AppError('unsupported'));
    await load();
    expect((cubit.state as VideoPlayerError).code, 'unsupported');
  });
  test('LRN-02: heartbeat sends pending spans and uses server done', () async {
    await load();
    advance();
    tick();
    await _drain();
    expect(repo.saves.single.$1, 'v');
    expect(repo.saves.single.$2.fromS, 12);
    expect(repo.saves.single.$2.toS, 26);
    expect(repo.saves.single.$3, 26);
    expect((cubit.state as VideoPlayerReady).done, isTrue);
    tick();
    await _drain();
    expect(repo.saves, hasLength(1));
  });
  test('LRN-02: playing toggle pauses and flushes', () async {
    await load();
    engine.statuses.add(EngineStatus.playing);
    advance();
    await cubit.togglePlay();
    expect(engine.pauses, 1);
    expect(repo.saves, hasLength(1));
    engine.statuses.add(EngineStatus.paused);
    await cubit.togglePlay();
    expect(engine.plays, 1);
  });
  test(
    'LRN-02: seek flushes old coverage and excludes skipped seconds',
    () async {
      await load();
      advance();
      cubit.seek(90);
      await _drain();
      engine.positions.add(90);
      engine.positions.add(91);
      tick();
      await _drain();
      expect(engine.seeks, [90]);
      expect(repo.saves.map((s) => (s.$2.fromS, s.$2.toS)), [
        (12, 26),
        (90, 91),
      ]);
    },
  );
  test(
    'SEC-01: fatal error recovers at current position, fourth fails',
    () async {
      await load();
      advance();
      for (var i = 0; i < 3; i++) {
        engine.errors.add(const AppError('internal'));
        await _drain();
      }
      expect(repo.requests, 4);
      expect(engine.attached.last.resumeS, 26);
      engine.errors.add(const AppError('internal'));
      await _drain();
      expect((cubit.state as VideoPlayerError).code, 'internal');
      expect(repo.requests, 4);
    },
  );
  test('LRN-02: recovery preserves speed and fullscreen changes', () async {
    await load();
    repo.pendingPlayback = Completer();
    engine.errors.add(const AppError('internal'));
    await _drain();
    cubit.setRate(1.5);
    await cubit.toggleFullscreen();
    repo.pendingPlayback!.complete(repo.playback);
    await _drain();
    final ready = cubit.state as VideoPlayerReady;
    expect(ready.rate, 1.5);
    expect(ready.fullscreen, isTrue);
    expect(engine.rates.last, 1.5);
  });
  test('SEC-01: stall at ten seconds requests a fresh grant', () async {
    await load();
    engine.statuses.add(EngineStatus.playing);
    now = now.add(const Duration(seconds: 10));
    tick();
    await _drain();
    expect(repo.requests, 2);
  });
  test('SEC-01: buffering stall also requests a fresh grant', () async {
    await load();
    engine.statuses.add(EngineStatus.playing);
    engine.statuses.add(EngineStatus.buffering);
    now = now.add(const Duration(seconds: 10));
    tick();
    await _drain();
    expect(repo.requests, 2);
  });
  test('SEC-01: recovery allowance renews after a minute', () async {
    await load();
    for (var i = 0; i < 3; i++) {
      engine.errors.add(const AppError('internal'));
      await _drain();
    }
    now = now.add(const Duration(seconds: 61));
    engine.errors.add(const AppError('internal'));
    await _drain();
    expect(cubit.state, isA<VideoPlayerReady>());
  });
  test('LRN-02: progress failure is surfaced', () async {
    repo.progress = const Failure(AppError('network'));
    await load();
    advance();
    tick();
    await _drain();
    expect((cubit.state as VideoPlayerError).code, 'network');
  });
  test(
    'LRN-02: close flushes once, disposes and stops later timer work',
    () async {
      await load();
      advance();
      await cubit.close();
      tick();
      await cubit.close();
      expect(repo.saves, hasLength(1));
      expect(engine.disposals, 1);
      expect(timers.every((timer) => !timer.isActive), isTrue);
    },
  );
  test(
    'LRN-02: in-flight progress response during close emits nothing',
    () async {
      await load();
      advance();
      repo.pendingSave = Completer();
      tick();
      await _drain();
      final states = <VideoPlayerState>[];
      final subscription = cubit.stream.listen(states.add);
      final closing = cubit.close();
      repo.pendingSave!.complete(const Success((pct: 80, done: true)));
      await closing;
      await _drain();
      expect(states, isEmpty);
      expect(repo.saves, hasLength(1));
      await subscription.cancel();
    },
  );
  test('LRN-02: error then close still flushes pending coverage', () async {
    await load();
    advance();
    engine.fullscreenFails = true;
    await cubit.toggleFullscreen();
    expect(cubit.state, isA<VideoPlayerError>());
    await cubit.close();
    expect(repo.saves, hasLength(1));
    expect((repo.saves.single.$2.fromS, repo.saves.single.$2.toS), (12, 26));
  });
  test(
    'LRN-02: error then retry flushes before replacing the tracker',
    () async {
      await load();
      advance();
      engine.fullscreenFails = true;
      await cubit.toggleFullscreen();
      await cubit.retry();
      expect(repo.saves, hasLength(1));
      expect(cubit.state, isA<VideoPlayerReady>());
    },
  );
  test('LRN-02: load response after close cannot attach or emit', () async {
    repo.pendingPlayback = Completer();
    final loading = load();
    await _drain();
    await cubit.close();
    repo.pendingPlayback!.complete(repo.playback);
    await loading;
    expect(engine.attached, isEmpty);
  });
  test('LRN-02: attach response after close cannot emit Ready', () async {
    engine.pendingAttach = Completer();
    final loading = load();
    await _drain();
    expect(engine.attached, hasLength(1));
    await cubit.close();
    engine.pendingAttach!.complete(const Success(null));
    await loading;
    expect(cubit.state, isNot(isA<VideoPlayerReady>()));
    expect(engine.disposals, 1);
  });
  test(
    'LRN-02: heartbeat saves are serialized while a response is pending',
    () async {
      await load();
      advance();
      repo.pendingSave = Completer();
      tick();
      await _drain();
      for (var s = 27; s <= 40; s++) {
        engine.positions.add(s.toDouble());
      }
      tick();
      await _drain();
      expect(repo.saves, hasLength(1));
      repo.pendingSave!.complete(const Success((pct: 80, done: true)));
      await _drain();
      expect(repo.saves.map((s) => (s.$2.fromS, s.$2.toS)), [
        (12, 26),
        (26, 40),
      ]);
    },
  );
  test('LRN-02: rate accepts exact supported speeds and ignores two', () async {
    await load();
    cubit
      ..setRate(1.25)
      ..setRate(1.5)
      ..setRate(1)
      ..setRate(2);
    expect(engine.rates, [1.25, 1.5, 1]);
    expect((cubit.state as VideoPlayerReady).rate, 1);
  });
  test('LRN-02: fullscreen toggles and browser Escape updates state', () async {
    await load();
    await cubit.toggleFullscreen();
    expect(engine.fullscreen, isTrue);
    expect((cubit.state as VideoPlayerReady).fullscreen, isTrue);
    engine.fullscreens.add(false);
    expect((cubit.state as VideoPlayerReady).fullscreen, isFalse);
    await cubit.toggleFullscreen();
    await cubit.toggleFullscreen();
    expect(engine.fullscreen, isFalse);
  });
}
