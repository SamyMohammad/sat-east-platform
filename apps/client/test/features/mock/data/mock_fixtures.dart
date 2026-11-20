/// Server-shaped JSON for the student mock RPCs (`docs/07` §1.1, the
/// `private.mock_stage` / `private.mock_module_payload` functions).
const groupId = '11111111-1111-1111-1111-111111111111';
const attemptId = '22222222-2222-2222-2222-222222222222';
const courseId = '33333333-3333-3333-3333-333333333333';
const resultId = '44444444-4444-4444-4444-444444444444';

Map<String, Object?> hubJson() => {
  'passed_topics': 7,
  'forms': [
    {'form_no': 1, 'k': 1, 'need': 3, 'state': 'finished'},
    {'form_no': 2, 'k': 2, 'need': 6, 'state': 'in_progress'},
    {'form_no': 3, 'k': 3, 'need': 7, 'state': 'available'},
    {'form_no': 4, 'k': 4, 'need': 12, 'state': 'locked'},
  ],
  'active_group': groupId,
};

Map<String, Object?> moduleJson({List<Object?>? answers}) => {
  'stage': 'module',
  'group_id': groupId,
  'module_no': 1,
  'attempt_id': attemptId,
  'title': 'Module 1',
  'time_limit_s': 2100,
  'deadline': '2026-11-17T10:35:00+00:00',
  'server_now': '2026-11-17T10:01:30.123456+00:00',
  'warn_s': 300,
  'questions': [
    {
      'id': 'q1',
      'type': 'mcq',
      'stem_md': r'What is $1+1$?',
      'choices': [
        {'label': 'A', 'body_md': '1'},
        {'label': 'B', 'body_md': '2'},
        {'label': 'C', 'body_md': '3'},
        {'label': 'D', 'body_md': '4'},
      ],
    },
    {'id': 'q2', 'type': 'spr', 'stem_md': 'Solve.', 'choices': <Object?>[]},
  ],
  'answers':
      answers ??
      [
        {
          'question_id': 'q1',
          'answer': 'B',
          'marked': true,
          'eliminated': ['A', 'D'],
        },
        {
          'question_id': 'q2',
          'answer': null,
          'marked': false,
          'eliminated': <Object?>[],
        },
      ],
  'client_seq': 4,
};

Map<String, Object?> gapJson() => {
  'stage': 'gap',
  'group_id': groupId,
  'gap_until': '2026-11-17T10:37:00+00:00',
  'server_now': '2026-11-17T10:35:01+00:00',
};

Map<String, Object?> finishedJson() => {
  'stage': 'finished',
  'group_id': groupId,
  'result_id': resultId,
};

Map<String, Object?> resultRowJson({
  Object? estLow = 560,
  Object? estHigh = 620,
}) => {
  'id': resultId,
  'route': 'hard',
  'raw_m1': 18,
  'raw_m2': 15,
  'est_low': estLow,
  'est_high': estHigh,
  'domain_breakdown': [
    {'domain': 'Algebra', 'correct': 9, 'total': 13},
    {'domain': 'Geometry and Trigonometry', 'correct': 4, 'total': 7},
  ],
};
