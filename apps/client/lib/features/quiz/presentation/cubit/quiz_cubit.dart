import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/time/ticker.dart';
import 'package:sat_east_client/features/quiz/domain/entities/quiz.dart';
import 'package:sat_east_client/features/quiz/domain/repositories/quiz_repository.dart';
import 'package:sat_east_client/features/quiz/presentation/cubit/quiz_attempt_clock.dart';
import 'package:sat_east_client/features/quiz/presentation/cubit/quiz_save_queue.dart';
import 'package:sat_east_client/features/quiz/presentation/cubit/quiz_state.dart';

class QuizCubit extends Cubit<QuizState> {
  QuizCubit(this._repository, this._now, this._ticker)
    : super(const QuizLoading());

  final QuizRepository _repository;
  final DateTime Function() _now;
  final Ticker _ticker;
  StreamSubscription<void>? _tickSub;
  QuizAttemptClock? _clock;
  QuizSaveQueue? _saves;
  Future<void>? _submission;
  int _generation = 0;
  bool _autoSubmitted = false;

  Future<void> start(String topicId) async {
    if (isClosed) return;
    final generation = ++_generation;
    final cancelTicker = _tickSub?.cancel();
    _tickSub = null;
    _saves?.dispose();
    _saves = null;
    _clock = null;
    _submission = null;
    _autoSubmitted = false;
    emit(const QuizLoading());
    if (cancelTicker != null) {
      await cancelTicker;
      if (isClosed || generation != _generation) return;
    }
    final result = await _repository.start(topicId);
    if (isClosed || generation != _generation) return;
    switch (result) {
      case Failure(:final error):
        emit(QuizFailed(error));
      case Success(:final value):
        _startSession(value, generation);
    }
  }

  void _startSession(QuizSession session, int generation) {
    if (session.questions.isEmpty) {
      emit(const QuizFailed(AppError(ErrorCodes.poolExhausted)));
      return;
    }
    final clock = QuizAttemptClock(session, _now)
      ..show(session.questions.first.id);
    _clock = clock;
    _saves = QuizSaveQueue(
      clientSeq: session.clientSeq,
      now: _now,
      isActive: () => !isClosed && generation == _generation,
      save: _save,
      onError: (error) => _saveError(generation, error),
      onDeadlinePassed: () => unawaited(timeUp()),
    );
    emit(
      QuizRunning(
        session: session,
        remaining: clock.remaining,
        answers: Map.unmodifiable({
          for (final entry in session.answers.entries)
            entry.key: entry.value.answer,
        }),
        marked: Set.unmodifiable({
          for (final entry in session.answers.entries)
            if (entry.value.marked) entry.key,
        }),
      ),
    );
    _tickSub = _ticker(const Duration(seconds: 1)).listen((_) => _tick());
    if (clock.remaining <= Duration.zero) unawaited(timeUp());
  }

  void _tick() {
    final current = _running;
    final clock = _clock;
    if (current == null || clock == null) return;
    final remaining = _autoSubmitted ? Duration.zero : clock.remaining;
    emit(current.copyWith(remaining: remaining));
    if (remaining <= Duration.zero) {
      unawaited(timeUp());
    } else if (!current.submitting) {
      _saves?.tick();
    }
  }

  void select(String label) {
    final current = _editable;
    if (current == null) return;
    final question = current.session.questions[current.index];
    if (question.kind != QuizKind.mcq ||
        !question.choices.any((choice) => choice.label == label)) {
      return;
    }
    _answer(current, label);
  }

  void sprChanged(String text) {
    final current = _editable;
    if (current == null ||
        current.session.questions[current.index].kind != QuizKind.spr) {
      return;
    }
    _answer(current, text);
  }

  void _answer(QuizRunning current, String answer) {
    final id = current.session.questions[current.index].id;
    if (current.answers[id] == answer) return;
    emit(
      current.copyWith(
        answers: Map.unmodifiable({...current.answers, id: answer}),
      ),
    );
    _saves?.enqueue(id);
  }

  void toggleMark() {
    final current = _editable;
    if (current == null) return;
    final id = current.session.questions[current.index].id;
    final marked = Set<String>.of(current.marked);
    if (!marked.remove(id)) marked.add(id);
    emit(current.copyWith(marked: Set.unmodifiable(marked)));
    _saves?.enqueue(id);
  }

  void goTo(int index) {
    final current = _editable;
    if (current == null ||
        index < 0 ||
        index >= current.session.questions.length ||
        index == current.index) {
      return;
    }
    _clock?.show(current.session.questions[index].id);
    emit(current.copyWith(index: index));
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
    final current = _running;
    if (current != null) {
      emit(current.copyWith(timerHidden: !current.timerHidden));
    }
  }

  Future<Result<SaveOutcome>> _save(String id, int seq) {
    final current = _running;
    final clock = _clock;
    if (current == null || clock == null) {
      return Future.value(const Failure(AppError(ErrorCodes.internal)));
    }
    return _repository.save(
      attemptId: current.session.attemptId,
      questionId: id,
      answer: current.answers[id],
      marked: current.marked.contains(id),
      timeMs: clock.timeMs(id),
      eliminated: const [],
      clientSeq: seq,
    );
  }

  void _saveError(int generation, AppError? error) {
    if (isClosed || generation != _generation) return;
    final current = _running;
    if (current != null) {
      emit(current.copyWith(saveError: error, clearSaveError: error == null));
    }
  }

  Future<void> timeUp() {
    final current = _running;
    if (current == null || _autoSubmitted) return Future.value();
    _autoSubmitted = true;
    emit(current.copyWith(remaining: Duration.zero));
    return submit();
  }

  Future<void> submit() {
    final current = _running;
    final saves = _saves;
    if (current == null || saves == null) return Future.value();
    final pending = _submission;
    if (pending != null) return pending;
    _clock?.pause();
    emit(current.copyWith(submitting: true, clearSubmitError: true));
    return _submission = _submit(current.session, saves, _generation);
  }

  Future<void> _submit(
    QuizSession session,
    QuizSaveQueue saves,
    int generation,
  ) async {
    await saves.flushForSubmit();
    if (isClosed || generation != _generation) return;
    final current = _running;
    if (!_autoSubmitted &&
        current != null &&
        (_clock?.remaining ?? current.remaining) <= Duration.zero) {
      _autoSubmitted = true;
      emit(current.copyWith(remaining: Duration.zero));
    }
    if (!_autoSubmitted && saves.hasPending) {
      _submissionFailed(
        saves.error ?? const AppError(ErrorCodes.internal),
        session,
        saves,
      );
      return;
    }
    final result = await _repository.submit(session.attemptId);
    if (isClosed || generation != _generation) return;
    switch (result) {
      case Failure(:final error):
        _submissionFailed(error, session, saves);
      case Success(:final value):
        saves.dispose();
        final cancelTicker = _tickSub?.cancel();
        _tickSub = null;
        if (cancelTicker != null) {
          await cancelTicker;
          if (isClosed || generation != _generation) return;
        }
        emit(QuizSubmitted(value));
    }
  }

  void _submissionFailed(
    AppError error,
    QuizSession session,
    QuizSaveQueue saves,
  ) {
    _submission = null;
    final current = _running;
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
      clock.show(session.questions[current.index].id);
      saves.resume();
    }
  }

  QuizRunning? get _running =>
      !isClosed && state is QuizRunning ? state as QuizRunning : null;

  QuizRunning? get _editable {
    final current = _running;
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
    final cancelTicker = _tickSub?.cancel();
    _tickSub = null;
    if (cancelTicker != null) {
      await cancelTicker;
      if (isClosed) return;
    }
    return super.close();
  }
}
