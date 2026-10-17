import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/quiz/domain/entities/quiz.dart';
import 'package:sat_east_client/features/quiz/domain/repositories/quiz_repository.dart';
import 'package:sat_east_client/features/quiz/presentation/cubit/quiz_cubit.dart';
import 'package:sat_east_client/features/quiz/presentation/cubit/quiz_state.dart';

part 'quiz_autosave_cases.dart';
part 'quiz_clock_cases.dart';
part 'quiz_lifecycle_cases.dart';
part 'quiz_submit_cases.dart';

void main() {
  _autosaveCases();
  _clockCases();
  _lifecycleCases();
  _submitCases();

  test('PRC-03: start loads the server session', () async {
    final harness = _Harness();
    addTearDown(harness.close);
    await harness.cubit.start('topic');
    expect(harness.running.session, harness.repo.session);
    expect(harness.running.index, 0);
    expect(harness.running.remaining, const Duration(minutes: 20));
    expect(harness.running.answers, isEmpty);
    expect(harness.running.marked, isEmpty);
    expect(harness.running.timerHidden, isFalse);
    expect(harness.running.submitting, isFalse);
    expect(harness.repo.started, ['topic']);
  });

  for (final code in [
    ErrorCodes.notAuthenticated,
    ErrorCodes.invalidInput,
    ErrorCodes.practiceNeeded,
    ErrorCodes.cooldownActive,
    ErrorCodes.topicLocked,
    ErrorCodes.accessExpired,
    ErrorCodes.notEnrolled,
    ErrorCodes.poolExhausted,
    ErrorCodes.network,
    ErrorCodes.internal,
  ]) {
    test('PRC-03: start preserves $code failure', () async {
      final h = _Harness();
      addTearDown(h.close);
      h.repo.startResult = Failure(AppError(code));
      await h.cubit.start('topic');
      expect(h.cubit.state, QuizFailed(AppError(code)));
      expect(h.ticks.hasListener, isFalse);
    });
  }

  test('PRC-03: resume restores answers, marks and server deadline', () async {
    final h = _Harness();
    addTearDown(h.close);
    h.repo.session = _session(
      answers: const {
        'mcq': SavedAnswer(answer: 'B', marked: true),
        'spr': SavedAnswer(marked: true),
      },
      clientSeq: 9,
      remaining: const Duration(minutes: 7),
    );
    await h.cubit.start('topic');
    expect(h.running.index, 0);
    expect(h.running.answers, {'mcq': 'B', 'spr': null});
    expect(h.running.marked, {'mcq', 'spr'});
    expect(h.running.remaining, const Duration(minutes: 7));
    h.cubit.select('A');
    await _settle();
    expect(h.repo.saves.single.clientSeq, 10);
  });

  test('PRC-03: start exposes loading until the response settles', () async {
    final h = _Harness();
    addTearDown(h.close);
    final response = Completer<Result<QuizSession>>();
    h.repo.onStart = (_) => response.future;
    final pending = h.cubit.start('topic');
    expect(h.cubit.state, const QuizLoading());
    response.complete(Success(h.repo.session));
    await pending;
    expect(h.cubit.state, isA<QuizRunning>());
  });
}

class _Harness {
  _Harness() {
    cubit = QuizCubit(repo, () => clock, (period) {
      expect(period, const Duration(seconds: 1));
      return ticks.stream;
    });
  }

  final repo = _Repository();
  final ticks = StreamController<void>.broadcast(sync: true);
  DateTime clock = DateTime.utc(2026, 10, 17, 12);
  late final QuizCubit cubit;

  QuizRunning get running => cubit.state as QuizRunning;

  Future<void> tick(Duration elapsed) async {
    clock = clock.add(elapsed);
    ticks.add(null);
    await _settle();
  }

  Future<void> close() async {
    await cubit.close();
    await ticks.close();
  }
}

class _Repository implements QuizRepository {
  QuizSession session = _session();
  Result<QuizSession>? startResult;
  Future<Result<QuizSession>> Function(String)? onStart;
  Future<Result<SaveOutcome>> Function(_Save)? onSave;
  Future<Result<QuizReport>> Function(String)? onSubmit;
  Result<QuizReport> submitResult = const Success(_report);
  final started = <String>[];
  final saves = <_Save>[];
  final submitted = <String>[];

  @override
  Future<Result<QuizSession>> start(String topicId) async {
    started.add(topicId);
    return onStart?.call(topicId) ?? startResult ?? Success(session);
  }

  @override
  Future<Result<SaveOutcome>> save({
    required String attemptId,
    required String questionId,
    required int timeMs,
    required bool marked,
    required List<String> eliminated,
    required int clientSeq,
    String? answer,
  }) async {
    final call = _Save(
      attemptId: attemptId,
      questionId: questionId,
      timeMs: timeMs,
      marked: marked,
      eliminated: List.of(eliminated),
      clientSeq: clientSeq,
      answer: answer,
    );
    saves.add(call);
    return onSave?.call(call) ?? const Success(SaveOutcome.saved);
  }

  @override
  Future<Result<QuizReport>> submit(String attemptId) async {
    submitted.add(attemptId);
    return onSubmit?.call(attemptId) ?? submitResult;
  }
}

QuizSession _session({
  String attemptId = 'attempt',
  Map<String, SavedAnswer> answers = const {},
  int clientSeq = 0,
  Duration remaining = const Duration(minutes: 20),
}) => QuizSession(
  attemptId: attemptId,
  title: '1.1 Algebra',
  timeLimit: const Duration(minutes: 20),
  deadline: DateTime.utc(2026, 10, 17, 12).add(remaining),
  serverNow: DateTime.utc(2026, 10, 17, 12),
  warnAt: const Duration(minutes: 5),
  questions: const [
    QuizQuestion(
      id: 'mcq',
      kind: QuizKind.mcq,
      difficulty: 'E',
      stemMd: 'Solve.',
      choices: [QuizChoice('A', 'One'), QuizChoice('B', 'Two')],
    ),
    QuizQuestion(
      id: 'spr',
      kind: QuizKind.spr,
      difficulty: 'M',
      stemMd: 'Solve.',
      choices: [],
    ),
  ],
  answers: answers,
  clientSeq: clientSeq,
);

class _Save {
  const _Save({
    required this.attemptId,
    required this.questionId,
    required this.timeMs,
    required this.marked,
    required this.eliminated,
    required this.clientSeq,
    this.answer,
  });

  final String attemptId;
  final String questionId;
  final String? answer;
  final int timeMs;
  final bool marked;
  final List<String> eliminated;
  final int clientSeq;
}

const _network = AppError(ErrorCodes.network);
const _report = QuizReport(
  scoreRaw: 9,
  scoreTotal: 12,
  scorePct: 75,
  passMark: 75,
  passed: true,
  nextTopic: (id: 'next', title: 'Next topic'),
  retakeAt: null,
);

Future<void> _settle() async {
  for (var i = 0; i < 30; i++) {
    await Future<void>.value();
  }
}
