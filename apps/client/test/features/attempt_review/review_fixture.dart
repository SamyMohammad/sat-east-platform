Map<String, Object?> reviewPayload({bool visible = true}) => {
  'summary': {
    'score_raw': 14,
    'score_total': 20,
    'score_pct': 70,
    'pass_mark': null,
    'passed': null,
    'keys_visible': visible,
  },
  'questions': [
    {
      'id': 'q1',
      'type': 'mcq',
      'stem_md': r'Solve $x+1=2$.',
      'choices': [
        {'label': 'B', 'body_md': '1'},
      ],
      'my_answer': 'A',
      'is_correct': false,
      'time_ms': 100,
      'skills': <Object?>[],
      'key': {'choice': 'B'},
      'explanation_md': r'Because $x=1$.',
    },
  ],
};
