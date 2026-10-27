import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/practice/domain/entities/practice.dart';
import 'package:sat_east_client/features/practice/domain/repositories/practice_repository.dart';
import 'package:sat_east_client/features/practice/presentation/cubit/practice_state.dart';
import 'package:sat_east_client/shared/widgets/question_view/rep_outcome.dart';

class PracticeCubit extends Cubit<PracticeState> {
  PracticeCubit(this._repository, this._now) : super(const PracticeLoading());

  final PracticeRepository _repository;
  final DateTime Function() _now;
  String? _topicId;
  DateTime? _shownAt;
  int _correctFirstTry = 0;
  int _generation = 0;

  Future<void> start(String topicId) async {
    if (isClosed) return;
    final generation = ++_generation;
    _topicId = topicId;
    _correctFirstTry = 0;
    _shownAt = null;
    emit(const PracticeLoading());
    final result = await _repository.start(topicId);
    if (isClosed || generation != _generation) return;
    switch (result) {
      case Success(:final value):
        if (value.questions.isEmpty) {
          emit(const PracticeFailed(AppError(ErrorCodes.poolExhausted)));
          return;
        }
        _shownAt = _now();
        emit(PracticeInProgress(set: value, index: 0));
      case Failure(:final error):
        emit(PracticeFailed(error));
    }
  }

  void select(String label) {
    final current = _answering;
    if (current == null ||
        current.checkError != null ||
        current.set.questions[current.index].kind != PracticeKind.mcq ||
        current.selected == label) {
      return;
    }
    emit(_updated(current, selected: label));
  }

  void sprChanged(String text) {
    final current = _answering;
    if (current == null ||
        current.checkError != null ||
        current.set.questions[current.index].kind != PracticeKind.spr ||
        current.sprText == text) {
      return;
    }
    emit(_updated(current, sprText: text));
  }

  Future<void> check() async {
    final current = _answering;
    final shownAt = _shownAt;
    if (current == null || shownAt == null) return;
    final question = current.set.questions[current.index];
    final answer = switch (question.kind) {
      PracticeKind.mcq => current.selected ?? '',
      PracticeKind.spr => current.sprText.trim(),
    };
    if (answer.trim().isEmpty) return;
    final generation = _generation;
    final checkedAt = _now();
    final elapsed = checkedAt.difference(shownAt).inMilliseconds;
    emit(
      _updated(
        current,
        feedback: const Checking(),
        checkError: current.checkError,
      ),
    );
    final result = await _repository.check(
      attemptId: current.set.attemptId,
      questionId: question.id,
      answer: answer,
      timeMs: elapsed < 0 ? 0 : elapsed,
    );
    if (isClosed || generation != _generation) return;
    switch (result) {
      case Failure(:final error):
        emit(
          switch (error.code) {
            ErrorCodes.notesNeeded ||
            ErrorCodes.topicLocked ||
            ErrorCodes.accessExpired ||
            ErrorCodes.notEnrolled => PracticeFailed(error),
            _ => _updated(current, checkError: error),
          },
        );
      case Success(:final value):
        _shownAt = checkedAt;
        switch (value) {
          case CheckMiss(:final hintMd, :final misconceptionMd):
            final missed = current.firstTry ?? answer;
            emit(
              _updated(
                current,
                feedback: MissedOnce(
                  missed: missed,
                  hintMd: hintMd,
                  misconceptionMd: misconceptionMd,
                ),
                firstTry: missed,
              ),
            );
          case CheckCorrect(:final tryNo):
            if (tryNo == 1) _correctFirstTry++;
            emit(
              _updated(
                current,
                feedback: Done(value),
                outcome: tryNo == 1 ? RepOutcome.firstTry : RepOutcome.missed,
              ),
            );
          case CheckRevealed():
            emit(
              _updated(
                current,
                feedback: Done(value),
                outcome: RepOutcome.missed,
              ),
            );
        }
    }
  }

  void next() {
    final current = state;
    if (isClosed ||
        current is! PracticeInProgress ||
        current.feedback is! Done) {
      return;
    }
    final index = current.index + 1;
    if (index == current.set.questions.length) {
      emit(
        PracticeSummary(
          correctFirstTry: _correctFirstTry,
          total: current.set.questions.length,
        ),
      );
      return;
    }
    _shownAt = _now();
    emit(
      PracticeInProgress(
        set: current.set,
        index: index,
        outcomes: current.outcomes,
      ),
    );
  }

  Future<Result<void>> report(String questionId, String reason, String? note) {
    final current = state;
    if (isClosed ||
        current is! PracticeInProgress ||
        current.set.questions[current.index].id != questionId) {
      return Future.value(const Failure(AppError(ErrorCodes.invalidInput)));
    }
    return _repository.report(questionId, reason, note);
  }

  Future<void> practiceMore() {
    final topicId = _topicId;
    return topicId == null ? Future<void>.value() : start(topicId);
  }

  PracticeInProgress? get _answering {
    final current = state;
    if (isClosed || current is! PracticeInProgress) return null;
    return switch (current.feedback) {
      Answering() || MissedOnce() => current,
      Checking() || Done() => null,
    };
  }
}

PracticeInProgress _updated(
  PracticeInProgress current, {
  String? selected,
  String? sprText,
  PracticeStep? feedback,
  String? firstTry,
  AppError? checkError,
  RepOutcome? outcome,
}) => PracticeInProgress(
  set: current.set,
  index: current.index,
  selected: selected ?? current.selected,
  sprText: sprText ?? current.sprText,
  feedback: feedback ?? current.feedback,
  firstTry: firstTry ?? current.firstTry,
  checkError: checkError,
  outcomes: outcome == null || current.outcomes.length > current.index
      ? current.outcomes
      : [...current.outcomes, outcome],
);
