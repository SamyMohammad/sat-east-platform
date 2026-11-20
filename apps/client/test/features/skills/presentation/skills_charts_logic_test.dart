import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/features/skills/domain/entities/skills_overview.dart';
import 'package:sat_east_client/features/skills/presentation/skills_copy.dart';
import 'package:sat_east_client/features/skills/presentation/widgets/chart_dash.dart';
import 'package:sat_east_client/features/skills/presentation/widgets/skill_sparkline.dart';

DomainMastery _d(String name, double? mean) => DomainMastery(
  domain: name,
  mean: mean,
  band: MasteryBand.building,
  practised: mean == null ? 0 : 1,
  total: 1,
);

SkillMastery _skill({
  int attempts = 5,
  double? accuracy = 82,
  Duration? avgTime = const Duration(seconds: 72),
}) => SkillMastery(
  code: 'X',
  name: 'X',
  domain: 'D',
  mastery: 50,
  attempts: attempts,
  band: MasteryBand.building,
  accuracy: accuracy,
  avgTime: avgTime,
);

DateTime _day(int day) => DateTime.utc(2026, 10, day);

TrendPoint _p(int day, double mastery) =>
    TrendPoint(weekStart: DateTime.utc(2026, 10, day), mastery: mastery);

void main() {
  group('ANL-01b: SkillsCopy.duration', () {
    test('ANL-01b: seconds_only_under_a_minute', () {
      expect(SkillsCopy.duration(const Duration(seconds: 45)), '45s');
    });

    test('ANL-01b: minutes_and_seconds', () {
      expect(SkillsCopy.duration(const Duration(seconds: 72)), '1m 12s');
    });

    test('ANL-01b: whole_minutes_drop_seconds', () {
      expect(SkillsCopy.duration(const Duration(minutes: 2)), '2m');
    });

    test('ANL-01b: never_below_one_second', () {
      expect(SkillsCopy.duration(const Duration(milliseconds: 200)), '1s');
    });

    test('ANL-01b: rounds_milliseconds_to_the_nearest_second', () {
      expect(SkillsCopy.duration(const Duration(milliseconds: 2400)), '2s');
      expect(SkillsCopy.duration(const Duration(milliseconds: 2600)), '3s');
    });
  });

  group('ANL-01b: SkillsCopy.accuracyLine', () {
    test('ANL-01b: accuracy_and_speed', () {
      expect(SkillsCopy.accuracyLine(_skill()), '82% correct · 1m 12s avg');
    });

    test('ANL-01b: accuracy_only_without_time', () {
      expect(SkillsCopy.accuracyLine(_skill(avgTime: null)), '82% correct');
    });

    test('ANL-01b: hidden_without_attempts', () {
      expect(SkillsCopy.accuracyLine(_skill(attempts: 0)), isNull);
    });

    test('ANL-01b: hidden_without_accuracy', () {
      expect(SkillsCopy.accuracyLine(_skill(accuracy: null)), isNull);
    });
  });

  group('ANL-01b: SkillsCopy.trendDelta', () {
    test('ANL-01b: positive_has_plus', () {
      expect(
        SkillsCopy.trendDelta(6, since: _day(12), until: _day(19)),
        '+6 this week',
      );
    });

    test('ANL-01b: negative_uses_true_minus', () {
      expect(
        SkillsCopy.trendDelta(-3, since: _day(12), until: _day(19)),
        '−3 this week',
      );
    });

    test('ANL-01b: zero_is_no_change', () {
      expect(
        SkillsCopy.trendDelta(0, since: _day(12), until: _day(19)),
        'No change',
      );
    });

    test('ANL-01b: gap_of_two_weeks_names_the_start_date', () {
      expect(
        SkillsCopy.trendDelta(6, since: _day(5), until: _day(19)),
        '+6 since Oct 5',
      );
      expect(
        SkillsCopy.trendDelta(-3, since: _day(5), until: _day(19)),
        '−3 since Oct 5',
      );
    });

    test('ANL-01b: gap_of_a_few_days_is_not_this_week', () {
      expect(
        SkillsCopy.trendDelta(4, since: _day(15), until: _day(19)),
        '+4 since Oct 15',
      );
    });

    test('ANL-01b: no_change_stays_plain_whatever_the_gap', () {
      expect(
        SkillsCopy.trendDelta(0, since: _day(5), until: _day(19)),
        'No change',
      );
    });
  });

  group('ANL-01b: SkillsCopy domain labels', () {
    test('ANL-01b: label_has_number_and_band_word', () {
      expect(
        SkillsCopy.domainLabel(
          const DomainMastery(
            domain: 'Algebra',
            mean: 78.2,
            band: MasteryBand.strong,
            practised: 3,
            total: 4,
          ),
        ),
        'Algebra · 78 · Strong',
      );
    });

    test('ANL-01b: label_for_unstarted_domain', () {
      expect(SkillsCopy.domainLabel(_d('Data', null)), 'Data · Not started');
    });
  });

  group('ANL-01b: DomainRanking', () {
    test('ANL-01b: picks_highest_and_lowest_practised', () {
      final domains = [_d('A', 60), _d('B', 30), _d('C', 90), _d('D', null)];

      expect(domains.strongest?.domain, 'C');
      expect(domains.weakest?.domain, 'B');
    });

    test('ANL-01b: no_practised_domain_gives_nothing', () {
      final domains = [_d('A', null), _d('B', null)];

      expect(domains.strongest, isNull);
      expect(domains.weakest, isNull);
    });

    test('ANL-01b: single_practised_domain_has_no_focus', () {
      final domains = [_d('A', 55), _d('B', null)];

      expect(domains.strongest?.domain, 'A');
      expect(domains.weakest, isNull);
    });
  });

  group('ANL-01b: validStrongAt', () {
    test('ANL-01b: accepts_one_to_one_hundred', () {
      expect(validStrongAt(75), 75);
      expect(validStrongAt(1), 1);
      expect(validStrongAt(100), 100);
    });

    test('ANL-01b: null_and_out_of_range_skip_the_target', () {
      expect(validStrongAt(null), isNull);
      expect(validStrongAt(0), isNull);
      expect(validStrongAt(-5), isNull);
      expect(validStrongAt(101), isNull);
      expect(validStrongAt(double.nan), isNull);
    });
  });

  group('ANL-01b: DomainRanking.nextToStart', () {
    test('ANL-01b: first_unstarted_domain', () {
      final domains = [_d('A', 55), _d('B', null), _d('C', null)];

      expect(domains.nextToStart?.domain, 'B');
    });

    test('ANL-01b: none_when_all_started', () {
      expect([_d('A', 55), _d('B', 10)].nextToStart, isNull);
    });
  });

  group('ANL-01b: sparklineRange', () {
    test('ANL-01b: uses_own_min_and_max', () {
      expect(sparklineRange([40, 70, 55]), (40.0, 70.0));
    });

    test('ANL-01b: small_span_is_widened_to_ten_around_the_middle', () {
      final (min, max) = sparklineRange([60, 62]);

      expect(max - min, 10);
      expect((min + max) / 2, 61);
    });

    test('ANL-01b: flat_line_gets_the_minimum_span', () {
      expect(sparklineRange([50, 50, 50]), (45.0, 55.0));
    });

    test('ANL-01b: span_of_exactly_ten_is_kept', () {
      expect(sparklineRange([30, 40]), (30.0, 40.0));
    });
  });

  group('ANL-01b: sparkline delta text', () {
    test('ANL-01b: size_only_without_sign', () {
      expect(SkillsCopy.sparkDelta(12), '12');
      expect(SkillsCopy.sparkDelta(-5), '5');
      expect(SkillsCopy.sparkDelta(0), '0');
    });

    test('ANL-01b: spoken_form_names_direction', () {
      expect(
        SkillsCopy.sparkDeltaSpoken(12, since: _day(12)),
        'up 12 points since Oct 12',
      );
      expect(
        SkillsCopy.sparkDeltaSpoken(-5, since: _day(12)),
        'down 5 points since Oct 12',
      );
      expect(
        SkillsCopy.sparkDeltaSpoken(0, since: _day(12)),
        'no change since Oct 12',
      );
    });

    test('ANL-01b: span_delta_is_last_minus_first', () {
      expect([_p(5, 40), _p(12, 70), _p(19, 52)].spanDelta, 12);
      expect([_p(19, 52)].spanDelta, isNull);
    });
  });

  group('ANL-01b: domain value', () {
    test('ANL-01b: number_and_band', () {
      expect(
        SkillsCopy.domainValue(
          const DomainMastery(
            domain: 'A',
            mean: 78,
            band: MasteryBand.strong,
            practised: 1,
            total: 1,
          ),
        ),
        '78 · Strong',
      );
      expect(SkillsCopy.domainValue(_d('A', null)), 'Not started');
    });
  });

  group('ANL-01b: TrendDelta', () {
    test('ANL-01b: delta_of_last_two_points', () {
      expect([_p(5, 40), _p(12, 50), _p(19, 56)].weeklyDelta, 6);
    });

    test('ANL-01b: negative_delta', () {
      expect([_p(12, 60), _p(19, 57)].weeklyDelta, -3);
    });

    test('ANL-01b: fewer_than_two_points_has_no_delta', () {
      expect([_p(19, 57)].weeklyDelta, isNull);
      expect(<TrendPoint>[].weeklyDelta, isNull);
    });
  });
}
