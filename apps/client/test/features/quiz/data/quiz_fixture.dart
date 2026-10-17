Map<String, Object?> quizSessionPayload() => {
  'attempt_id': 'a1',
  'title': '1.1 Linear equations',
  'time_limit_s': 180,
  'deadline': '2026-10-17T15:03:00+03:00',
  'server_now': '2026-10-17T15:00:00+03:00',
  'warn_s': 300,
  'questions': [
    <String, Object?>{
      'id': 'q2',
      'type': 'spr',
      'difficulty': 'H',
      'stem_md': 'Solve x.',
      'choices': <Object?>[],
    },
    <String, Object?>{
      'id': 'q1',
      'type': 'mcq',
      'difficulty': 'E',
      'stem_md': 'What is 1+1?',
      'choices': [
        {'label': 'A', 'body_md': '1'},
        {'label': 'B', 'body_md': '2'},
      ],
    },
  ],
  'answers': <Object?>[],
  'client_seq': 0,
};

Map<String, Object?> quizReportPayload() => {
  'score_raw': 9,
  'score_total': 12,
  'score_pct': 75,
  'pass_mark': 75,
  'passed': true,
  'next_topic': {'id': 't2', 'title': 'Quadratics'},
  'retake_at': null,
};
