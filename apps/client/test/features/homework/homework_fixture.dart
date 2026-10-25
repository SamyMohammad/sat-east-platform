import 'package:sat_east_client/core/attempts/attempt_question.dart';
import 'package:sat_east_client/features/homework/domain/entities/homework.dart';

const homeworkSession = HomeworkSession(
  attemptId: 'hw1',
  title: 'Homework 1.1',
  questions: [
    AttemptQuestion(
      id: 'q1',
      kind: AttemptKind.mcq,
      difficulty: 'E',
      stemMd: 'One?',
      choices: [AttemptChoice('A', '1'), AttemptChoice('B', '2')],
    ),
    AttemptQuestion(
      id: 'q2',
      kind: AttemptKind.spr,
      difficulty: 'M',
      stemMd: 'Solve x.',
      choices: [],
    ),
  ],
  answers: {'q1': SavedAnswer(answer: 'B', marked: true)},
  clientSeq: 9,
);
const homeworkReport = HomeworkReport(
  attemptId: 'hw1',
  scoreRaw: 1,
  scoreTotal: 2,
  scorePct: 50,
);
Map<String, Object?> homeworkPayload() => {
  'attempt_id': 'hw1',
  'title': 'Homework 1.1',
  'client_seq': 9,
  'questions': [
    {
      'id': 'q1',
      'type': 'mcq',
      'difficulty': 'E',
      'stem_md': 'One?',
      'choices': [
        {'label': 'A', 'body_md': '1'},
        {'label': 'B', 'body_md': '2'},
      ],
    },
    {
      'id': 'q2',
      'type': 'spr',
      'difficulty': 'M',
      'stem_md': 'Solve x.',
      'choices': <Object?>[],
    },
  ],
  'answers': [
    {'question_id': 'q1', 'answer': 'B', 'marked': true},
  ],
};
Map<String, Object?> homeworkReportPayload() => {
  'attempt_id': 'hw1',
  'kind': 'homework',
  'score_raw': 1,
  'score_total': 2,
  'score_pct': 50,
};
