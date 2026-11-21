import 'package:sat_east_client/features/skills/domain/entities/skills_overview.dart';

const Map<String, Object?> skillsPayload = {
  'summary': {
    'solved': 12,
    'total': 40,
    'graded_answers': 31,
    'trend_min_answers': 10,
    'strong_at': 75,
  },
  'skills': [
    {
      'code': 'ALG.LIN',
      'name': 'Linear equations',
      'domain': 'Algebra',
      'mastery': 82.5,
      'attempts': 9,
      'band': 'strong',
      'accuracy': 82.0,
      'avg_time_ms': 72000,
      'history': [
        {'week_start': '2026-10-12', 'mastery': 70.5},
        {'week_start': '2026-10-19', 'mastery': 82.5},
      ],
    },
    {
      'code': 'ALG.SYS',
      'name': 'Systems of equations',
      'domain': 'Algebra',
      'mastery': 41,
      'attempts': 7,
      'band': 'weak',
      'accuracy': 50.0,
      'avg_time_ms': 45000,
      'history': <Object?>[],
    },
    {
      'code': 'GEO.CIR',
      'name': 'Circles',
      'domain': 'Geometry',
      'mastery': null,
      'attempts': 2,
      'band': 'thin',
      'accuracy': null,
      'avg_time_ms': null,
      'history': <Object?>[],
    },
  ],
  'domains': [
    {
      'domain': 'Algebra',
      'mean': 61.5,
      'band': 'building',
      'practised': 2,
      'total': 2,
    },
    {
      'domain': 'Geometry',
      'mean': null,
      'band': 'thin',
      'practised': 0,
      'total': 1,
    },
  ],
  'weak': [
    {
      'code': 'ALG.SYS',
      'name': 'Systems of equations',
      'mastery': 41,
      'topic_id': 't2',
      'topic_title': 'Systems',
    },
  ],
  'trend': [
    {'week_start': '2026-10-12', 'mastery': 48.5},
    {'week_start': '2026-10-19', 'mastery': 57},
  ],
  'topics': [
    {
      'topic_id': 't1',
      'title': 'Linear equations',
      'unit_title': 'Algebra',
      'solved': 5,
      'total': 10,
      'level': 'strong',
    },
    {
      'topic_id': 't2',
      'title': 'Systems',
      'unit_title': null,
      'solved': 1,
      'total': 8,
      'level': 'thin',
    },
  ],
};

Map<String, Object?> skillsPayloadWith(Map<String, Object?> overrides) => {
  ...skillsPayload,
  ...overrides,
};

/// Domain fixture matching [skillsPayload].
final skillsOverviewFixture = SkillsOverview(
  summary: const SkillsSummary(
    solved: 12,
    total: 40,
    gradedAnswers: 31,
    trendMinAnswers: 10,
    strongAt: 75,
  ),
  skills: [
    SkillMastery(
      code: 'ALG.LIN',
      name: 'Linear equations',
      domain: 'Algebra',
      mastery: 82.5,
      attempts: 9,
      band: MasteryBand.strong,
      accuracy: 82,
      avgTime: const Duration(seconds: 72),
      history: [
        TrendPoint(weekStart: DateTime.utc(2026, 10, 12), mastery: 70.5),
        TrendPoint(weekStart: DateTime.utc(2026, 10, 19), mastery: 82.5),
      ],
    ),
    const SkillMastery(
      code: 'ALG.SYS',
      name: 'Systems of equations',
      domain: 'Algebra',
      mastery: 41,
      attempts: 7,
      band: MasteryBand.weak,
      accuracy: 50,
      avgTime: Duration(seconds: 45),
    ),
    const SkillMastery(
      code: 'GEO.CIR',
      name: 'Circles',
      domain: 'Geometry',
      mastery: null,
      attempts: 2,
      band: MasteryBand.thin,
    ),
  ],
  domains: const [
    DomainMastery(
      domain: 'Algebra',
      mean: 61.5,
      band: MasteryBand.building,
      practised: 2,
      total: 2,
    ),
    DomainMastery(
      domain: 'Geometry',
      mean: null,
      band: MasteryBand.thin,
      practised: 0,
      total: 1,
    ),
  ],
  weak: const [
    WeakSkill(
      code: 'ALG.SYS',
      name: 'Systems of equations',
      mastery: 41,
      topicId: 't2',
      topicTitle: 'Systems',
    ),
  ],
  trend: [
    TrendPoint(weekStart: DateTime.utc(2026, 10, 12), mastery: 48.5),
    TrendPoint(weekStart: DateTime.utc(2026, 10, 19), mastery: 57),
  ],
  topics: const [
    TopicLevel(
      topicId: 't1',
      title: 'Linear equations',
      unitTitle: 'Algebra',
      solved: 5,
      total: 10,
      level: MasteryBand.strong,
    ),
    TopicLevel(
      topicId: 't2',
      title: 'Systems',
      unitTitle: null,
      solved: 1,
      total: 8,
      level: MasteryBand.thin,
    ),
  ],
);
