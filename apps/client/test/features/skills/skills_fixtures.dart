import 'package:sat_east_client/features/skills/domain/entities/skills_overview.dart';

const Map<String, Object?> skillsPayload = {
  'summary': {'solved': 12, 'total': 40, 'graded_answers': 31},
  'skills': [
    {
      'code': 'ALG.LIN',
      'name': 'Linear equations',
      'domain': 'Algebra',
      'mastery': 82.5,
      'attempts': 9,
      'band': 'strong',
    },
    {
      'code': 'ALG.SYS',
      'name': 'Systems of equations',
      'domain': 'Algebra',
      'mastery': 41,
      'attempts': 7,
      'band': 'weak',
    },
    {
      'code': 'GEO.CIR',
      'name': 'Circles',
      'domain': 'Geometry',
      'mastery': null,
      'attempts': 2,
      'band': 'thin',
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
  summary: const SkillsSummary(solved: 12, total: 40, gradedAnswers: 31),
  skills: const [
    SkillMastery(
      code: 'ALG.LIN',
      name: 'Linear equations',
      domain: 'Algebra',
      mastery: 82.5,
      attempts: 9,
      band: MasteryBand.strong,
    ),
    SkillMastery(
      code: 'ALG.SYS',
      name: 'Systems of equations',
      domain: 'Algebra',
      mastery: 41,
      attempts: 7,
      band: MasteryBand.weak,
    ),
    SkillMastery(
      code: 'GEO.CIR',
      name: 'Circles',
      domain: 'Geometry',
      mastery: null,
      attempts: 2,
      band: MasteryBand.thin,
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
