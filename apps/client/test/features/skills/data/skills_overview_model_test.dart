import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/features/skills/data/models/skills_overview_model.dart';
import 'package:sat_east_client/features/skills/domain/entities/skills_overview.dart';

import '../skills_fixtures.dart';

void main() {
  group('ANL-01: skillsOverviewFromJson', () {
    test('ANL-01: parses_full_payload', () {
      final overview = skillsOverviewFromJson(skillsPayload);

      expect(overview, skillsOverviewFixture);
      expect(overview.weak.single.topicId, 't2');
      expect(overview.topics.last.unitTitle, isNull);
    });

    test('ANL-01: unknown_band_is_thin', () {
      final overview = skillsOverviewFromJson(
        skillsPayloadWith({
          'skills': [
            {
              'code': 'X',
              'name': 'X',
              'domain': 'D',
              'mastery': 70,
              'attempts': 9,
              'band': 'legendary',
            },
          ],
        }),
      );

      expect(overview.skills.single.band, MasteryBand.thin);
    });

    test('ANL-01: null_mastery_allowed_for_thin', () {
      final overview = skillsOverviewFromJson(skillsPayload);

      expect(overview.skills.last.mastery, isNull);
      expect(overview.skills.last.band, MasteryBand.thin);
    });

    test('ANL-01: empty_lists_ok', () {
      final overview = skillsOverviewFromJson(
        skillsPayloadWith({
          'summary': {
            'solved': 0,
            'total': 0,
            'graded_answers': 0,
            'trend_min_answers': 10,
          },
          'skills': <Object?>[],
          'weak': <Object?>[],
          'trend': <Object?>[],
          'topics': <Object?>[],
        }),
      );

      expect(overview.skills, isEmpty);
      expect(overview.weak, isEmpty);
      expect(overview.trend, isEmpty);
      expect(overview.topics, isEmpty);
      expect(overview.summary.gradedAnswers, 0);
    });

    test('ANL-01: trend_min_answers_from_payload', () {
      final overview = skillsOverviewFromJson(
        skillsPayloadWith({
          'summary': {
            'solved': 1,
            'total': 2,
            'graded_answers': 3,
            'trend_min_answers': 17,
          },
        }),
      );

      expect(overview.summary.trendMinAnswers, 17);
    });

    test('ANL-01: missing_trend_min_answers_is_a_format_error', () {
      expect(
        () => skillsOverviewFromJson(
          skillsPayloadWith({
            'summary': {'solved': 1, 'total': 2, 'graded_answers': 3},
          }),
        ),
        throwsFormatException,
      );
    });

    test('ANL-01: missing_summary_is_a_format_error', () {
      expect(
        () => skillsOverviewFromJson({...skillsPayload}..remove('summary')),
        throwsFormatException,
      );
    });
  });
}
