import 'package:equatable/equatable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/features/homework/data/models/homework_model.dart';
import 'package:sat_east_client/features/mock/data/models/mock_models.dart';
import 'package:sat_east_client/features/mock/domain/entities/mock_entities.dart';
import 'package:sat_east_client/features/practice/data/models/practice_model.dart';
import 'package:sat_east_client/features/quiz/data/models/quiz_model.dart';

// NFR-07: answer keys and explanations never reach the client before submit.
// Each pre-submit payload below is poisoned with key-like fields; the parsed
// entity must not carry any of them.

const _poison = <String, Object?>{
  'correct_answer': 'LEAK-correct_answer',
  'answer_key': 'LEAK-answer_key',
  'explanation': 'LEAK-explanation',
  'explanation_md': 'LEAK-explanation_md',
  'key': 'LEAK-key',
  'hint_md': 'LEAK-hint_md',
};

/// Every string reachable through Equatable props, collections and records.
Iterable<String> _strings(Object? value) sync* {
  switch (value) {
    case String():
      yield value;
    case Equatable():
      for (final prop in value.props) {
        yield* _strings(prop);
      }
    case Iterable<Object?>():
      for (final item in value) {
        yield* _strings(item);
      }
    case Map<Object?, Object?>():
      for (final entry in value.entries) {
        yield* _strings(entry.key);
        yield* _strings(entry.value);
      }
    case (final Object? a, final Object? b):
      yield* _strings(a);
      yield* _strings(b);
    default:
      break;
  }
}

void _expectNoLeak(Object entity) {
  final leaked = _strings(entity).where((s) => s.contains('LEAK-')).toList();
  expect(leaked, isEmpty);
  expect(entity.toString(), isNot(contains('LEAK-')));
}

Map<String, Object?> _question(String id, {bool difficulty = true}) => {
  'id': id,
  'type': 'mcq',
  if (difficulty) 'difficulty': 'E',
  'stem_md': 'One?',
  'choices': [
    {'label': 'A', 'body_md': '1', ..._poison},
    {'label': 'B', 'body_md': '2'},
  ],
  ..._poison,
};

Map<String, Object?> _answer(String id) => {
  'question_id': id,
  'answer': 'A',
  'marked': false,
  ..._poison,
};

void main() {
  test('NFR-07 practice set drops key and explanation fields', () {
    final set = practiceSetFromJson({
      'attempt_id': 'a1',
      'rep_target': 3,
      'questions': [_question('q1')],
      ..._poison,
    });
    _expectNoLeak(set);
    expect(set.questions.single.props, hasLength(5));
  });

  test('NFR-07 quiz session drops key and explanation fields', () {
    final session = quizSessionFromJson({
      'attempt_id': 'a1',
      'title': 'Quiz',
      'time_limit_s': 600,
      'deadline': '2026-01-01T10:10:00Z',
      'server_now': '2026-01-01T10:00:00Z',
      'warn_s': 60,
      'client_seq': 1,
      'questions': [_question('q1')],
      'answers': [_answer('q1')],
      ..._poison,
    });
    _expectNoLeak(session);
    expect(session.questions.single.props, hasLength(5));
  });

  test('NFR-07 homework session drops key and explanation fields', () {
    final session = homeworkSessionFromJson({
      'attempt_id': 'hw1',
      'title': 'Homework',
      'client_seq': 1,
      'questions': [_question('q1')],
      'answers': [_answer('q1')],
      ..._poison,
    });
    _expectNoLeak(session);
    expect(session.questions.single.props, hasLength(5));
  });

  test('NFR-07 mock module drops key and explanation fields', () {
    final stage = mockStageFromJson({
      'stage': 'module',
      'group_id': 'g1',
      'module_no': 1,
      'attempt_id': 'a1',
      'title': 'Module 1',
      'time_limit_s': 600,
      'deadline': '2026-01-01T10:10:00Z',
      'server_now': '2026-01-01T10:00:00Z',
      'warn_s': 60,
      'client_seq': 1,
      'questions': [_question('q1', difficulty: false)],
      'answers': [_answer('q1')],
      ..._poison,
    });
    expect(stage, isA<MockModuleStage>());
    _expectNoLeak(stage);
    expect(
      (stage as MockModuleStage).module.questions.single.props,
      hasLength(5),
    );
  });
}
