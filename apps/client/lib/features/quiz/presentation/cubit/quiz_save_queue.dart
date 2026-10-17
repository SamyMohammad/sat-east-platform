import 'dart:async';

import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/quiz/domain/entities/quiz.dart';

/// One writer per attempt; pending question IDs always use the latest snapshot.
class QuizSaveQueue {
  QuizSaveQueue({
    required this._clientSeq,
    required this._now,
    required this._isActive,
    required this._save,
    required this._onError,
    required this._onDeadlinePassed,
  });

  static const _retryDelays = [
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
  ];

  final DateTime Function() _now;
  final bool Function() _isActive;
  final Future<Result<SaveOutcome>> Function(String, int) _save;
  final void Function(AppError?) _onError;
  final void Function() _onDeadlinePassed;
  int _clientSeq;
  int _failures = 0;
  Set<String> _pending = {};
  Completer<void>? _flight;
  DateTime? _retryAt;
  bool _paused = false;
  bool _disposed = false;
  bool _expired = false;
  bool _stopped = false;
  AppError? _error;

  bool get _active => !_disposed && _isActive();
  bool get hasPending => _pending.isNotEmpty;
  AppError? get error => _error;

  void enqueue(String questionId) {
    if (!_active || _stopped) return;
    _pending.add(questionId);
    _pump();
  }

  void tick() {
    if (!_active || _paused) return;
    final retryAt = _retryAt;
    if (retryAt != null && !_now().isBefore(retryAt)) _retryAt = null;
    _pump();
  }

  void _pump() {
    if (!_active ||
        _stopped ||
        _paused ||
        _flight != null ||
        _retryAt != null ||
        _pending.isEmpty) {
      return;
    }
    final id = _pending.first;
    _pending.remove(id);
    _launch(id);
  }

  void _launch(String id) {
    final done = Completer<void>();
    _flight = done;
    unawaited(
      _perform(id).then((_) {
        if (identical(_flight, done)) _flight = null;
        if (!done.isCompleted) done.complete();
        _pump();
      }),
    );
  }

  Future<void> _perform(String id) async {
    final result = await _save(id, ++_clientSeq);
    if (!_active) return;
    switch (result) {
      case Success():
        if (_pending.isEmpty) {
          _failures = 0;
          _retryAt = null;
          _error = null;
        }
        _onError(_error);
      case Failure(:final error) when error.code == ErrorCodes.deadlinePassed:
        _expired = true;
        _paused = true;
        _retryAt = null;
        _pending.clear();
        _onDeadlinePassed();
      case Failure(:final error) when error.code == ErrorCodes.invalidInput:
        _stopped = true;
        _retryAt = null;
        _pending = {id, ..._pending};
        _error = error;
        _onError(error);
      case Failure(:final error):
        _pending = {id, ..._pending};
        final delayIndex = _failures < _retryDelays.length
            ? _failures
            : _retryDelays.length - 1;
        _failures++;
        _retryAt = _now().add(_retryDelays[delayIndex]);
        _error = error;
        _onError(error);
    }
  }

  Future<void> flushForSubmit() async {
    _paused = true;
    _retryAt = null;
    final flight = _flight;
    if (flight != null) {
      await flight.future;
      if (!_active) return;
    }
    _retryAt = null;
    // Include failed in-flight saves, but try each pending question only once.
    final dirty = _pending.toList();
    for (final id in dirty) {
      if (!_active || _expired || _stopped) return;
      _pending.remove(id);
      _launch(id);
      final saving = _flight;
      if (saving != null) {
        await saving.future;
        if (!_active) return;
      }
    }
  }

  void resume() {
    if (!_active || _expired || _stopped) return;
    _paused = false;
    tick();
  }

  void flushOnClose() {
    if (!_active || _expired || _stopped) return;
    _paused = true;
    for (final id in _pending) {
      unawaited(_save(id, ++_clientSeq));
    }
    _pending.clear();
  }

  void dispose() {
    _disposed = true;
    _retryAt = null;
    _pending.clear();
    final flight = _flight;
    if (flight != null && !flight.isCompleted) flight.complete();
  }
}
