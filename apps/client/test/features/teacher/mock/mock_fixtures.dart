import 'package:sat_east_client/features/teacher/mock/domain/entities/mock_entities.dart';

const _domains = ['algebra', 'advanced_math', 'problem_solving', 'geometry'];
const _difficulties = ['easy', 'medium', 'hard'];

/// 19 cells summing to 66.
List<Map<String, Object?>> needPerFormJson() {
  final cells = <Map<String, Object?>>[];
  var left = 66;
  for (var i = 0; i < 19; i++) {
    final count = i == 18 ? left : (i < 10 ? 4 : 3);
    left -= count;
    cells.add({
      'domain': _domains[i % 4],
      'difficulty': _difficulties[i % 3],
      'type': i.isEven ? 'mcq' : 'spr',
      'count': count,
    });
  }
  return cells;
}

Map<String, Object?> overviewJson({
  List<Object?> missing = const [],
  int noDomain = 0,
}) => {
  'template': {
    'id': '11111111-1111-1111-1111-111111111111',
    'name': 'SAT Math',
    'blueprint': {'modules': 3},
  },
  'need_per_form': needPerFormJson(),
  'forms': [
    {
      'set_no': 1,
      'form_no': 1,
      'status': 'published',
      'published_at': '2026-11-10T09:30:00+00:00',
    },
    {'set_no': 1, 'form_no': 2, 'status': 'draft', 'published_at': null},
  ],
  'next_form': {'missing': missing, 'no_domain': noDomain},
};

Map<String, Object?> shortageCellJson() => {
  'domain': 'algebra',
  'difficulty': 'hard',
  'type': 'spr',
  'needed': 4,
  'available': 2,
  'modules': {'M1': 1, 'M2H': 3},
};

Map<String, Object?> formJson({String status = 'draft'}) => {
  'set_no': 1,
  'form_no': 2,
  'status': status,
  'published_at': status == 'published' ? '2026-11-11T10:00:00+00:00' : null,
  'modules': [
    for (final m in ['M1', 'M2E', 'M2H'])
      {
        'module': m,
        'questions': [
          for (var s = 1; s <= 22; s++)
            {
              'slot_no': s,
              'id': '$m-q$s',
              'external_ref': s.isEven ? null : 'REF-$m-$s',
              'type': s.isEven ? 'spr' : 'mcq',
              'difficulty': 'medium',
              'domain': 'algebra',
              'stem_md': 'Stem $m $s',
            },
        ],
      },
  ],
};

List<Map<String, Object?>> candidatesJson() => [
  {'id': 'c1', 'external_ref': 'REF-C1', 'stem_md': 'Candidate one'},
  {'id': 'c2', 'external_ref': null, 'stem_md': 'Candidate two'},
];

const parsedShortage = MockShortageCell(
  domain: 'algebra',
  difficulty: 'hard',
  type: 'spr',
  needed: 4,
  available: 2,
  modules: {'M1': 1, 'M2H': 3},
);
