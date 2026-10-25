import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/video/domain/services/video_engine.dart';
import 'package:web/web.dart' as web;

/// Owns one platform view and the browser resources shared by both engines.
abstract class WebVideoEngine implements VideoEngine, FullscreenVideoEngine {
  WebVideoEngine(String prefix, this.element) {
    viewType = '$prefix-${_nextId++}';
    element.style
      ..width = '100%'
      ..height = '100%';
    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int _) => element,
    );
    _fullscreenListener = ((web.Event _) {
      if (!disposed) {
        _fullscreen.add(web.document.fullscreenElement != null);
      }
    }).toJS;
    web.document.addEventListener('fullscreenchange', _fullscreenListener);
  }

  static int _nextId = 0;
  final web.HTMLElement element;
  final _positions = StreamController<double>.broadcast();
  final _statuses = StreamController<EngineStatus>.broadcast();
  final _errors = StreamController<AppError>.broadcast();
  final _fullscreen = StreamController<bool>.broadcast();
  late final JSFunction _fullscreenListener;
  bool disposed = false;

  @override
  late final String viewType;
  @override
  Stream<double> get position => _positions.stream;
  @override
  Stream<EngineStatus> get status => _statuses.stream;
  @override
  Stream<AppError> get fatalErrors => _errors.stream;
  @override
  Stream<bool> get fullscreenChanges => _fullscreen.stream;

  void emitPosition(double value) {
    if (!disposed && value.isFinite && value >= 0) _positions.add(value);
  }

  void emitStatus(EngineStatus value) {
    if (!disposed) _statuses.add(value);
  }

  void emitFatal() {
    if (!disposed) _errors.add(const AppError(ErrorCodes.internal));
  }

  @override
  Future<void> requestFullscreen() async {
    await web.document.documentElement!.requestFullscreen().toDart;
  }

  @override
  Future<void> exitFullscreen() async {
    if (web.document.fullscreenElement != null) {
      await web.document.exitFullscreen().toDart;
    }
  }

  Future<void> disposeBase() async {
    if (disposed) return;
    disposed = true;
    web.document.removeEventListener('fullscreenchange', _fullscreenListener);
    element.remove();
    await Future.wait([
      _positions.close(),
      _statuses.close(),
      _errors.close(),
      _fullscreen.close(),
    ]);
  }
}
