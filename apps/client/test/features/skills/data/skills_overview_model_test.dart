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

    test('ANL-01b: parses_new_chart_fields', () {
      final overview = skillsOverviewFromJson(skillsPayload);

      expect(overview.summary.strongAt, 75);
      final linear = overview.skills.first;
      expect(linear.accuracy, 82);
      expect(linear.avgTime, const Duration(seconds: 72));
      expect(linear.history, hasLength(2));
      expect(linear.history.last.mastery, 82.5);
      expect(overview.domains, hasLength(2));
      expect(overview.domains.first.domain, 'Algebra');
      expect(overview.domains.first.mean, 61.5);
      expect(overview.domains.first.band, MasteryBand.building);
      expect(overview.domains.last.mean, isNull);
      expect(overview.domains.last.band, MasteryBand.thin);
      expect(overview.domains.last.practised, 0);
      expect(overview.domains.last.total, 1);
    });

    test('ANL-01b: old_payload_without_chart_fields_uses_defaults', () {
      final overview = skillsOverviewFromJson(
        {
          ...skillsPayload,
          'summary': {
            'solved': 1,
            'total': 2,
            'graded_answers': 3,
            'trend_min_answers': 10,
          },
          'skills': [
            {
              'code': 'X',
              'name': 'X',
              'domain': 'D',
              'mastery': 70,
              'attempts': 9,
              'band': 'building',
            },
          ],
        }..remove('domains'),
      );

      expect(overview.summary.strongAt, isNull);
      expect(overview.skills.single.accuracy, isNull);
      expect(overview.skills.single.avgTime, isNull);
      expect(overview.skills.single.history, isEmpty);
      expect(overview.domains, isEmpty);
    });

    test('ANL-01b: null_history_and_domains_are_empty', () {
      final overview = skillsOverviewFromJson({
        ...skillsPayload,
        'domains': null,
        'skills': [
          {
            'code': 'X',
            'name': 'X',
            'domain': 'D',
            'mastery': 70,
            'attempts': 9,
            'band': 'building',
            'history': null,
          },
        ],
      });

      expect(overview.domains, isEmpty);
      expect(overview.skills.single.history, isEmpty);
    });

    test('ANL-01b: mistyped_domain_mean_is_a_format_error', () {
      expect(
        () => skillsOverviewFromJson(
          skillsPayloadWith({
            'domains': [
              {
                'domain': 'Algebra',
                'mean': 'high',
                'band': 'weak',
                'practised': 1,
                'total': 1,
              },
            ],
          }),
        ),
        throwsFormatException,
      );
    });
  });
}
