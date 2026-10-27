import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/attempts/answer_save_queue.dart';
import 'package:sat_east_client/core/attempts/attempt_question.dart';
import 'package:sat_east_client/core/attempts/save_outcome.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/time/ticker.dart';
import 'package:sat_east_client/features/homework/domain/repositories/homework_repository.dart';
import 'package:sat_east_client/features/homework/presentation/cubit/homework_state.dart';

class HomeworkCubit extends Cubit<HomeworkState> {
  HomeworkCubit(this._repository, this._now, this._ticker)
    : super(const HomeworkLoading());
  final HomeworkRepository _repository;
  final DateTime Function() _now;
  final Ticker _ticker;
  final _times = <String, int>{};
  DateTime? _shownAt;
  StreamSubscription<void>? _ticks;
  AnswerSaveQueue? _saves;
  Future<void>? _submission;
  Future<void>? _retrying;
  int _generation = 0;

  Future<void> start(String topicId) async {
    if (isClosed) return;
    final generation = ++_generation;
    _saves?.dispose();
    _saves = null;
    _submission = null;
    _retrying = null;
    _times.clear();
    final cancel = _ticks?.cancel();
    _ticks = null;
    emit(const HomeworkLoading());
    if (cancel != null) await cancel;
    if (isClosed || generation != _generation) return;
    final result = await _repository.start(topicId);
    if (isClosed || generation != _generation) return;
    switch (result) {
      case Failure(:final error):
        emit(HomeworkFailed(error));
      case Success(:final value):
        if (value.questions.isEmpty) {
          emit(const HomeworkFailed(AppError(ErrorCodes.poolExhausted)));
          return;
        }
        _shownAt = _now();
        _saves = AnswerSaveQueue(
          clientSeq: value.clientSeq,
          now: _now,
          isActive: () => !isClosed && generation == _generation,
          save: _save,
          onError: (_) => _saveChanged(generation),
          onChanged: () => _saveChanged(generation),
          onDeadlinePassed: () => _saveChanged(generation),
        );
        emit(
          HomeworkRunning(
            session: value,
            answers: Map.unmodifiable({
              for (final e in value.answers.entries) e.key: e.value.answer,
            }),
            marked: Set.unmodifiable({
              for (final e in value.answers.entries)
                if (e.value.marked) e.key,
            }),
          ),
        );
        _ticks = _ticker(const Duration(seconds: 1)).listen((_) {
          if (!isClosed && generation == _generation) _saves?.tick();
        });
    }
  }

  HomeworkRunning? get _running =>
      !isClosed && state is HomeworkRunning ? state as HomeworkRunning : null;
  HomeworkRunning? get _editable {
    final current = _running;
    return current != null && !current.submitting ? current : null;
  }

  void select(String label) {
    final current = _editable;
    if (current == null) return;
    final question = current.session.questions[current.index];
    if (question.kind != AttemptKind.mcq ||
        !question.choices.any((c) => c.label == label)) {
      return;
    }
    _answer(current, label);
  }

  void sprChanged(String text) {
    final current = _editable;
    if (current == null ||
        current.session.questions[current.index].kind != AttemptKind.spr) {
      return;
    }
    _answer(current, text);
  }

  void _answer(HomeworkRunning current, String answer) {
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

  void eliminate(String label) => _eliminate(label, remove: false);
  void restore(String label) => _eliminate(label, remove: true);
  void _eliminate(String label, {required bool remove}) {
    final current = _editable;
    if (current == null) return;
    final question = current.session.questions[current.index];
    if (question.kind != AttemptKind.mcq ||
        !question.choices.any((c) => c.label == label)) {
      return;
    }
    final labels = Set<String>.of(current.eliminated[question.id] ?? {});
    if (remove) {
      labels.remove(label);
    } else {
      labels.add(label);
    }
    emit(
      current.copyWith(
        eliminated: Map.unmodifiable({
          ...current.eliminated,
          question.id: Set<String>.unmodifiable(labels),
        }),
      ),
    );
    _saves?.enqueue(question.id);
  }

  void goTo(int index) {
    final current = _editable;
    if (current == null ||
        index < 0 ||
        index >= current.session.questions.length ||
        index == current.index) {
      return;
    }
    _pause(current);
    _shownAt = _now();
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

  void _pause(HomeworkRunning current) {
    final id = current.session.questions[current.index].id;
    _times[id] = _timeMs(id);
    _shownAt = null;
  }

  int _timeMs(String id) {
    final current = _running;
    final shown = _shownAt;
    final elapsed =
        current != null &&
            shown != null &&
            current.session.questions[current.index].id == id
        ? _now().difference(shown).inMilliseconds.clamp(0, 3600000)
        : 0;
    return (_times[id] ?? 0) + elapsed;
  }

  Future<Result<SaveOutcome>> _save(String id, int seq) {
    final current = _running;
    if (current == null) {
      return Future.value(const Failure(AppError(ErrorCodes.internal)));
    }
    return _repository.save(
      attemptId: current.session.attemptId,
      questionId: id,
      answer: current.answers[id],
      timeMs: _timeMs(id),
      marked: current.marked.contains(id),
      eliminated: (current.eliminated[id] ?? {}).toList(),
      clientSeq: seq,
    );
  }

  void _saveChanged(int generation) {
    if (generation != _generation) return;
    final current = _running;
    final saves = _saves;
    if (current == null || saves == null) return;
    emit(
      current.copyWith(
        saving: saves.isSaving,
        saveError: saves.error,
        clearSaveError: saves.error == null,
      ),
    );
  }

  Future<void> retrySave() {
    final saves = _saves;
    if (_editable == null || saves == null) return Future.value();
    final pending = _retrying;
    if (pending != null) return pending;
    return _retrying = _retry(saves, _generation);
  }

  Future<void> _retry(AnswerSaveQueue saves, int generation) async {
    await saves.flushForSubmit();
    if (isClosed || generation != _generation) return;
    _retrying = null;
    saves.resume();
    _saveChanged(generation);
  }

  Future<void> submit() {
    final current = _running;
    final saves = _saves;
    if (current == null || saves == null) return Future.value();
    final pending = _submission;
    if (pending != null) return pending;
    _pause(current);
    emit(current.copyWith(submitting: true, clearSubmitError: true));
    return _submission = _submit(saves, _generation);
  }

  Future<void> _submit(AnswerSaveQueue saves, int generation) async {
    await _retrying;
    if (isClosed || generation != _generation) return;
    await saves.flushForSubmit();
    if (isClosed || generation != _generation) return;
    final current = _running;
    if (current == null) return;
    if (saves.hasPending && !saves.isStopped) {
      _submitFailed(saves.error ?? const AppError(ErrorCodes.internal), saves);
      return;
    }
    final result = await _repository.submit(current.session.attemptId);
    if (isClosed || generation != _generation) return;
    switch (result) {
      case Failure(:final error):
        _submitFailed(error, saves);
      case Success(:final value):
        saves.dispose();
        final cancel = _ticks?.cancel();
        _ticks = null;
        if (cancel != null) await cancel;
        if (!isClosed && generation == _generation) {
          emit(HomeworkSubmitted(value));
        }
    }
  }

  void _submitFailed(AppError error, AnswerSaveQueue saves) {
    _submission = null;
    final current = _running;
    if (current == null) return;
    _shownAt = _now();
    emit(current.copyWith(submitting: false, submitError: error));
    saves.resume();
  }

  @override
  Future<void> close() async {
    if (isClosed) return;
    final current = _running;
    if (current != null) _pause(current);
    _saves?.flushOnClose();
    ++_generation;
    _saves?.dispose();
    await _ticks?.cancel();
    return super.close();
  }
}
