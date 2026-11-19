import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/attempts/answer_save_queue.dart';
import 'package:sat_east_client/core/attempts/attempt_question.dart';
import 'package:sat_east_client/core/attempts/pending_answers.dart';
import 'package:sat_east_client/core/attempts/save_outcome.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/time/ticker.dart';
import 'package:sat_east_client/features/mock/domain/entities/mock_entities.dart';
import 'package:sat_east_client/features/mock/domain/repositories/mock_repository.dart';
import 'package:sat_east_client/features/mock/presentation/cubit/mock_attempt_clock.dart';
import 'package:sat_east_client/features/mock/presentation/cubit/mock_exam_state.dart';

/// Drives one mock run (`module 1 -> gap -> module 2 -> finished`). The server
/// owns time, routing and score: this cubit only shows what it returns, and
/// after any doubt (`deadline_passed`, `invalid_input`) asks `session()`.
class MockExamCubit extends Cubit<MockExamState> {
  MockExamCubit(
    this._repository,
    this._now,
    this._ticker,
    this._pending,
    this.groupId,
  ) : super(const MockExamLoading());

  static const Set<String> _fallbackCodes = {
    ErrorCodes.deadlinePassed,
    ErrorCodes.invalidInput,
  };

  final MockRepository _repository;
  final DateTime Function() _now;
  final Ticker _ticker;
  final PendingAnswers _pending;
  final String groupId;

  StreamSubscription<void>? _tickSub;
  MockAttemptClock? _clock;
  MockCountdown? _countdown;
  AnswerSaveQueue? _saves;
  Future<void>? _submission;
  int _generation = 0;
  bool _autoSubmitted = false;
  bool _gapSynced = false;
  bool _resyncing = false;

  bool _stale(int generation) => isClosed || generation != _generation;

  /// Loads the run from the server whatever stage it is in; safe to call again
  /// after leaving the page (the server may have moved on meanwhile).
  Future<void> start() async {
    if (isClosed) return;
    final generation = ++_generation;
    _resyncing = false;
    emit(const MockExamLoading());
    if (!await _teardown(generation)) return;
    await _resolve(
      _repository.session,
      generation,
      (error) => emit(MockExamFailed(error)),
    );
  }

  // ---- stage handling ----

  Future<void> _resolve(
    Future<Result<MockStage>> Function(String groupId) fetch,
    int generation,
    void Function(AppError error) onError,
  ) async {
    final result = await fetch(groupId);
    if (_stale(generation)) return;
    switch (result) {
      case Failure(:final error):
        onError(error);
      case Success(:final value):
        await _enter(value, generation, onError);
    }
  }

  Future<void> _enter(
    MockStage stage,
    int generation,
    void Function(AppError error) onError, {
    bool followMarker = true,
  }) async {
    if (!await _teardown(generation)) return;
    switch (stage) {
      case MockModuleStage(:final module):
        _openModule(module, generation);
      case MockGapStage():
        _openGap(stage);
      case MockFinishedStage(:final resultId):
        emit(MockExamFinished(resultId: resultId));
        await _loadResult(resultId, generation);
      case MockModuleStartedStage():
        // No payload yet: the next stage comes from session().
        if (!followMarker) {
          onError(const AppError(ErrorCodes.internal));
          return;
        }
        final next = await _repository.session(groupId);
        if (_stale(generation)) return;
        switch (next) {
          case Failure(:final error):
            onError(error);
          case Success(:final value):
            await _enter(value, generation, onError, followMarker: false);
        }
    }
  }

  /// Releases the running module's timers and queue before the next stage.
  Future<bool> _teardown(int generation) async {
    _saves?.dispose();
    _saves = null;
    _clock = null;
    _countdown = null;
    _submission = null;
    _autoSubmitted = false;
    _gapSynced = false;
    final cancel = _tickSub?.cancel();
    _tickSub = null;
    if (cancel != null) {
      await cancel;
      if (_stale(generation)) return false;
    }
    return true;
  }

  void _listen() {
    _tickSub = _ticker(const Duration(seconds: 1)).listen((_) => _tick());
  }

  // ---- module ----

  void _openModule(MockModule module, int generation) {
    if (module.questions.isEmpty) {
      emit(const MockExamFailed(AppError(ErrorCodes.internal)));
      return;
    }
    final clock = MockAttemptClock(
      deadline: module.deadline,
      serverNow: module.serverNow,
      now: _now,
    )..show(module.questions.first.id);
    _clock = clock;
    final answers = {
      for (final entry in module.answers.entries) entry.key: entry.value.answer,
    };
    final marked = {
      for (final entry in module.answers.entries)
        if (entry.value.marked) entry.key,
    };
    final eliminated = {
      for (final entry in module.answers.entries)
        if (entry.value.eliminated.isNotEmpty)
          entry.key: entry.value.eliminated,
    };
    // Unacknowledged local answers win over the server copy (outbox).
    final local = _pending.forAttempt(module.attemptId);
    for (final entry in local.entries) {
      answers[entry.key] = entry.value.answer;
      if (entry.value.marked) {
        marked.add(entry.key);
      } else {
        marked.remove(entry.key);
      }
      if (entry.value.eliminated.isEmpty) {
        eliminated.remove(entry.key);
      } else {
        eliminated[entry.key] = entry.value.eliminated;
      }
    }
    _saves = AnswerSaveQueue(
      clientSeq: module.clientSeq,
      now: _now,
      isActive: () => !_stale(generation),
      save: _save,
      onError: (error) => _saveError(generation, error),
      onDeadlinePassed: () {
        _pending.clearAttempt(module.attemptId);
        // A running submit gets the same answer from the server itself.
        if (_submission == null) unawaited(_resync(generation));
      },
    );
    emit(
      MockExamModule(
        module: module,
        remaining: clock.remaining,
        answers: Map.unmodifiable(answers),
        marked: Set.unmodifiable(marked),
        eliminated: Map.unmodifiable({
          for (final entry in eliminated.entries)
            entry.key: Set<String>.unmodifiable(entry.value),
        }),
      ),
    );
    _listen();
    local.keys.forEach(_saves!.enqueue);
    if (clock.remaining <= Duration.zero) unawaited(timeUp());
  }

  void _tick() {
    final module = _module;
    final gap = _gap;
    if (module != null) {
      final remaining = _autoSubmitted
          ? Duration.zero
          : _clock?.remaining ?? module.remaining;
      emit(module.copyWith(remaining: remaining));
      if (remaining <= Duration.zero) {
        unawaited(timeUp());
      } else if (!module.submitting) {
        _saves?.tick();
      }
    } else if (gap != null) {
      final remaining = _countdown?.remaining ?? gap.remaining;
      emit(gap.copyWith(remaining: remaining));
      if (remaining <= Duration.zero && !_gapSynced) {
        _gapSynced = true;
        unawaited(_gapEnded(_generation));
      }
    }
  }

  void select(String label) {
    final current = _editable;
    if (current == null) return;
    final question = current.module.questions[current.index];
    if (question.kind != AttemptKind.mcq ||
        !question.choices.any((choice) => choice.label == label)) {
      return;
    }
    _answer(current, label);
  }

  void sprChanged(String text) {
    final current = _editable;
    if (current == null ||
        current.module.questions[current.index].kind != AttemptKind.spr) {
      return;
    }
    _answer(current, text);
  }

  void _answer(MockExamModule current, String answer) {
    final id = current.module.questions[current.index].id;
    if (current.answers[id] == answer) return;
    final next = current.copyWith(
      answers: Map.unmodifiable({...current.answers, id: answer}),
    );
    emit(next);
    _record(next, id);
  }

  void toggleMark() {
    final current = _editable;
    if (current == null) return;
    final id = current.module.questions[current.index].id;
    final marked = Set<String>.of(current.marked);
    if (!marked.remove(id)) marked.add(id);
    final next = current.copyWith(marked: Set.unmodifiable(marked));
    emit(next);
    _record(next, id);
  }

  /// Strikes a choice out, or restores it. The chosen answer cannot be struck.
  void toggleEliminate(String label) {
    final current = _editable;
    if (current == null) return;
    final question = current.module.questions[current.index];
    if (question.kind != AttemptKind.mcq ||
        !question.choices.any((choice) => choice.label == label) ||
        current.answers[question.id] == label) {
      return;
    }
    final labels = Set<String>.of(current.eliminated[question.id] ?? const {});
    if (!labels.remove(label)) labels.add(label);
    final map = Map<String, Set<String>>.of(current.eliminated);
    if (labels.isEmpty) {
      map.remove(question.id);
    } else {
      map[question.id] = Set.unmodifiable(labels);
    }
    final next = current.copyWith(eliminated: Map.unmodifiable(map));
    emit(next);
    _record(next, question.id);
  }

  /// Persists the change before queueing the save, so a reload cannot lose it.
  void _record(MockExamModule next, String id) {
    _pending.put(
      next.module.attemptId,
      id,
      answer: next.answers[id],
      marked: next.marked.contains(id),
      timeMs: _clock?.timeMs(id) ?? 0,
      eliminated: next.eliminated[id] ?? const {},
    );
    _saves?.enqueue(id);
  }

  void goTo(int index) {
    final current = _editable;
    if (current == null ||
        index < 0 ||
        index >= current.module.questions.length) {
      return;
    }
    if (index == current.index) {
      if (current.reviewOpen) emit(current.copyWith(reviewOpen: false));
      return;
    }
    _clock?.show(current.module.questions[index].id);
    emit(current.copyWith(index: index, reviewOpen: false));
  }

  void next() {
    final current = _editable;
    if (current != null) goTo(current.index + 1);
  }

  void prev() {
    final current = _editable;
    if (current != null) goTo(current.index - 1);
  }

  void toggleTimer() {
    final current = _module;
    if (current != null) {
      emit(current.copyWith(timerHidden: !current.timerHidden));
    }
  }

  void openReview() {
    final current = _editable;
    if (current != null) emit(current.copyWith(reviewOpen: true));
  }

  void closeReview() {
    final current = _module;
    if (current != null && current.reviewOpen) {
      emit(current.copyWith(reviewOpen: false));
    }
  }

  Future<Result<SaveOutcome>> _save(String id, int seq) async {
    final current = _module;
    final clock = _clock;
    if (current == null || clock == null) {
      return const Failure(AppError(ErrorCodes.internal));
    }
    final attemptId = current.module.attemptId;
    // A newer local edit made while this call is in flight bumps the rev, so
    // the ack below leaves it in the outbox.
    final rev = _pending.revOf(attemptId, id);
    // save_answer overwrites time_ms; after a reload the clock restarts at 0.
    final stored = _pending.forAttempt(attemptId)[id]?.timeMs ?? 0;
    final result = await _repository.save(
      attemptId: attemptId,
      questionId: id,
      answer: current.answers[id],
      marked: current.marked.contains(id),
      timeMs: math.max(stored, clock.timeMs(id)),
      eliminated: (current.eliminated[id] ?? const <String>{}).toList()..sort(),
      clientSeq: seq,
    );
    if (result is Success<SaveOutcome> && rev != null) {
      _pending.ack(attemptId, id, rev);
    }
    return result;
  }

  void _saveError(int generation, AppError? error) {
    if (_stale(generation)) return;
    if (error?.code == ErrorCodes.invalidInput) {
      // The module is no longer in progress: its unsent answers are dead, and
      // the server knows where the run stands.
      final current = _module;
      if (current != null) _pending.clearAttempt(current.module.attemptId);
      if (_submission == null) unawaited(_resync(generation));
      return;
    }
    final current = _module;
    if (current != null) {
      emit(current.copyWith(saveError: error, clearSaveError: error == null));
    }
  }

  /// Asks the server where the run stands and renders that.
  Future<void> _resync(int generation) async {
    if (_resyncing) return;
    _resyncing = true;
    try {
      await _resolve(_repository.session, generation, (error) {
        final current = _module;
        if (current != null) emit(current.copyWith(saveError: error));
      });
    } finally {
      _resyncing = false;
    }
  }

  // ---- submit ----

  Future<void> timeUp() {
    final current = _module;
    if (current == null || _autoSubmitted) return Future.value();
    _autoSubmitted = true;
    emit(current.copyWith(remaining: Duration.zero));
    return submitModule();
  }

  Future<void> submitModule() {
    final current = _module;
    final saves = _saves;
    if (current == null || saves == null) return Future.value();
    final pending = _submission;
    if (pending != null) return pending;
    _clock?.pause();
    emit(current.copyWith(submitting: true, clearSubmitError: true));
    return _submission = _submit(current.module, saves, _generation);
  }

  Future<void> _submit(
    MockModule module,
    AnswerSaveQueue saves,
    int generation,
  ) async {
    await saves.flushForSubmit();
    if (_stale(generation)) return;
    final current = _module;
    if (!_autoSubmitted &&
        current != null &&
        (_clock?.remaining ?? current.remaining) <= Duration.zero) {
      _autoSubmitted = true;
      emit(current.copyWith(remaining: Duration.zero));
    }
    if (!_autoSubmitted && saves.hasPending) {
      await _submitFailed(
        saves.error ?? const AppError(ErrorCodes.internal),
        saves,
        module,
        generation,
      );
      return;
    }
    final result = await _repository.submit(module.attemptId);
    if (_stale(generation)) return;
    switch (result) {
      case Failure(:final error):
        await _submitFailed(error, saves, module, generation);
      case Success(:final value):
        _pending.clearAttempt(module.attemptId);
        await _enter(
          value,
          generation,
          (error) => _showSubmitError(error, saves, module),
        );
    }
  }

  Future<void> _submitFailed(
    AppError error,
    AnswerSaveQueue saves,
    MockModule module,
    int generation,
  ) async {
    if (_fallbackCodes.contains(error.code)) {
      // The server already closed the module: follow its stage.
      _submission = null;
      await _resolve(
        _repository.session,
        generation,
        (e) => _showSubmitError(e, saves, module),
      );
      return;
    }
    _showSubmitError(error, saves, module);
  }

  void _showSubmitError(
    AppError error,
    AnswerSaveQueue saves,
    MockModule module,
  ) {
    _submission = null;
    final current = _module;
    final clock = _clock;
    if (current == null || clock == null) return;
    final remaining = _autoSubmitted ? Duration.zero : clock.remaining;
    if (remaining <= Duration.zero) _autoSubmitted = true;
    emit(
      current.copyWith(
        remaining: remaining,
        submitting: false,
        submitError: error,
      ),
    );
    if (remaining > Duration.zero) {
      clock.show(module.questions[current.index].id);
      saves.resume();
    }
  }

  // ---- gap ----

  void _openGap(MockGapStage stage) {
    final countdown = MockCountdown(
      until: stage.gapUntil,
      serverNow: stage.serverNow,
      now: _now,
    );
    _countdown = countdown;
    emit(
      MockExamGap(
        groupId: stage.groupId,
        gapUntil: stage.gapUntil,
        remaining: countdown.remaining,
      ),
    );
    _listen();
  }

  /// The break is over: the server starts module 2 when asked for the session.
  Future<void> _gapEnded(int generation) async {
    final gap = _gap;
    if (gap == null || gap.startingModule2) return;
    await _resolve(_repository.session, generation, _gapError);
  }

  void _gapError(AppError error) {
    final gap = _gap;
    if (gap != null) {
      emit(gap.copyWith(startingModule2: false, error: error));
    }
  }

  /// "Start module 2 now": the server is idempotent, so a retry is safe.
  Future<void> startModule2() async {
    final gap = _gap;
    if (gap == null || gap.startingModule2) return;
    final generation = _generation;
    _gapSynced = true;
    emit(gap.copyWith(startingModule2: true, clearError: true));
    await _resolve(_repository.startModule2, generation, _gapError);
  }

  // ---- result ----

  Future<void> _loadResult(String resultId, int generation) async {
    final result = await _repository.result(resultId);
    if (_stale(generation)) return;
    emit(switch (result) {
      Success(:final value) => MockExamFinished(
        resultId: resultId,
        result: value,
      ),
      Failure(:final error) => MockExamFinished(
        resultId: resultId,
        resultError: error,
      ),
    });
  }

  Future<void> retryResult() async {
    final current = state;
    if (isClosed || current is! MockExamFinished || current.loading) return;
    emit(MockExamFinished(resultId: current.resultId));
    await _loadResult(current.resultId, _generation);
  }

  // ---- state helpers ----

  MockExamModule? get _module =>
      !isClosed && state is MockExamModule ? state as MockExamModule : null;

  MockExamGap? get _gap =>
      !isClosed && state is MockExamGap ? state as MockExamGap : null;

  MockExamModule? get _editable {
    final current = _module;
    return current != null &&
            !current.submitting &&
            current.remaining > Duration.zero
        ? current
        : null;
  }

  @override
  Future<void> close() async {
    _clock?.pause();
    _saves?.flushOnClose();
    ++_generation;
    _saves?.dispose();
    final cancel = _tickSub?.cancel();
    _tickSub = null;
    if (cancel != null) {
      await cancel;
      if (isClosed) return;
    }
    return super.close();
  }
}
