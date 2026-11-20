import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/skills/domain/entities/skills_overview.dart';
import 'package:sat_east_client/features/skills/presentation/cubit/skills_cubit.dart';
import 'package:sat_east_client/features/skills/presentation/cubit/skills_state.dart';
import 'package:sat_east_client/features/skills/presentation/screens/skills_screen.dart';
import 'package:sat_east_client/features/skills/presentation/widgets/domain_bars.dart';
import 'package:sat_east_client/features/skills/presentation/widgets/domain_radar_card.dart';
import 'package:sat_east_client/features/skills/presentation/widgets/mastery_band_chip.dart';
import 'package:sat_east_client/features/skills/presentation/widgets/mastery_trend_chart.dart';
import 'package:sat_east_client/features/skills/presentation/widgets/skill_sparkline.dart';
import 'package:sat_east_client/shared/widgets/growing_bar.dart';

import '../skills_fixtures.dart';

class _FakeSkillsCubit extends MockCubit<SkillsState> implements SkillsCubit {}

const _fourDomains = [
  DomainMastery(
    domain: 'Algebra',
    mean: 78.2,
    band: MasteryBand.strong,
    practised: 3,
    total: 3,
  ),
  DomainMastery(
    domain: 'Geometry',
    mean: 41,
    band: MasteryBand.weak,
    practised: 2,
    total: 3,
  ),
  DomainMastery(
    domain: 'Data',
    mean: null,
    band: MasteryBand.thin,
    practised: 0,
    total: 2,
  ),
  DomainMastery(
    domain: 'Advanced Math',
    mean: 60,
    band: MasteryBand.building,
    practised: 2,
    total: 2,
  ),
];

SkillsOverview _overview({
  List<DomainMastery> domains = const [],
  List<SkillMastery>? skills,
  List<TrendPoint>? trend,
  List<WeakSkill>? weak,
}) => SkillsOverview(
  summary: skillsOverviewFixture.summary,
  skills: skills ?? skillsOverviewFixture.skills,
  weak: weak ?? skillsOverviewFixture.weak,
  trend: trend ?? skillsOverviewFixture.trend,
  topics: skillsOverviewFixture.topics,
  domains: domains,
);

Future<void> _pump(
  WidgetTester tester,
  SkillsOverview overview, {
  double width = 360,
  double height = 3000,
  bool reduced = false,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final cubit = _FakeSkillsCubit();
  whenListen(
    cubit,
    const Stream<SkillsState>.empty(),
    initialState: SkillsLoaded(overview, 'c1'),
  );
  when(cubit.retry).thenAnswer((_) async {});
  final router = GoRouter(
    initialLocation: '/skills',
    routes: [
      GoRoute(
        path: '/skills',
        builder: (_, _) => Scaffold(
          body: BlocProvider<SkillsCubit>.value(
            value: cubit,
            child: const SkillsView(),
          ),
        ),
      ),
      GoRoute(
        path: '/courses',
        builder: (_, _) => const Scaffold(body: Text('courses page')),
        routes: [
          GoRoute(
            path: 'topics/:id',
            builder: (_, s) =>
                Scaffold(body: Text('topic:${s.pathParameters['id']}')),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduced,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

double _scrollOffset(WidgetTester tester) => tester
    .state<ScrollableState>(find.byType(Scrollable).first)
    .position
    .pixels;

void main() {
  group('ANL-01b: domain radar', () {
    testWidgets('ANL-01b: wide_radar_labels_have_number_and_band_word', (
      tester,
    ) async {
      await _pump(tester, _overview(domains: _fourDomains), width: 1280);

      expect(find.text('Domain mastery'), findsOneWidget);
      expect(find.byType(DomainBars), findsNothing);
      expect(find.text('Algebra · 78 · Strong'), findsOneWidget);
      expect(find.text('Geometry · 41 · Weak'), findsOneWidget);
      expect(find.text('Advanced Math · 60 · Building'), findsOneWidget);
      expect(find.text('Data · Not started'), findsOneWidget);
      expect(find.byKey(const ValueKey('radar-legend-Algebra')), findsNothing);
    });

    testWidgets('ANL-01b: narrow_radar_has_a_legend_with_full_values', (
      tester,
    ) async {
      await _pump(tester, _overview(domains: _fourDomains));

      expect(find.text('Domain mastery'), findsOneWidget);
      expect(find.byType(DomainBars), findsNothing);
      for (final (domain, value) in [
        ('Algebra', '78 · Strong'),
        ('Geometry', '41 · Weak'),
        ('Advanced Math', '60 · Building'),
        ('Data', 'Not started'),
      ]) {
        final row = find.byKey(ValueKey('radar-legend-$domain'));
        expect(row, findsOneWidget, reason: domain);
        expect(
          find.descendant(of: row, matching: find.text(domain)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: row, matching: find.text(value)),
          findsOneWidget,
          reason: value,
        );
      }
      // No long label is drawn around the radar at this width.
      expect(find.text('Algebra · 78 · Strong'), findsNothing);
    });

    testWidgets('ANL-01b: legend_never_truncates_a_long_domain_name', (
      tester,
    ) async {
      const long = 'Problem-Solving and Data Analysis';
      final domains = [
        ..._fourDomains.take(3),
        const DomainMastery(
          domain: long,
          mean: null,
          band: MasteryBand.thin,
          practised: 0,
          total: 2,
        ),
      ];
      await _pump(tester, _overview(domains: domains), textScale: 2);

      final row = find.byKey(const ValueKey('radar-legend-$long'));
      expect(tester.takeException(), isNull);
      final name = tester.renderObject<RenderParagraph>(
        find.descendant(of: row, matching: find.text(long)),
      );
      expect(name.didExceedMaxLines, isFalse);
      final value = tester.renderObject<RenderParagraph>(
        find.descendant(of: row, matching: find.text('Not started')),
      );
      expect(value.didExceedMaxLines, isFalse);
      expect(tester.getRect(row).right, lessThanOrEqualTo(360));
    });

    testWidgets('ANL-01b: narrow_radar_fills_the_card_width', (tester) async {
      await _pump(tester, _overview(domains: _fourDomains));

      final card = tester.getRect(find.byType(DomainRadarCard));
      final plot = tester.getRect(
        find.byKey(const ValueKey('radar-plot')),
      );
      expect(plot.width, closeTo(card.width - 2 * 16, 0.5));
      expect(plot.height, greaterThan(plot.width * 0.9));
    });

    testWidgets('ANL-01b: radar_chips_name_strongest_and_focus_with_icons', (
      tester,
    ) async {
      await _pump(tester, _overview(domains: _fourDomains));

      final strongest = find.byKey(const ValueKey('radar-chip-strongest'));
      final focus = find.byKey(const ValueKey('radar-chip-focus'));
      expect(
        find.descendant(
          of: strongest,
          matching: find.text('Strongest: Algebra'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: focus, matching: find.text('Focus next: Geometry')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: strongest, matching: find.byIcon(AppIcons.moveUp)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: focus, matching: find.byIcon(AppIcons.moveDown)),
        findsOneWidget,
      );
    });

    testWidgets('ANL-01b: radar_announces_one_summary', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _overview(domains: _fourDomains));

      expect(
        find.bySemanticsLabel(
          'Domain mastery: Algebra 78 strong, Geometry 41 weak, '
          'Data not started, Advanced Math 60 building',
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    for (final (name, width, finder) in <(String, double, Finder Function())>[
      ('axis_label', 1280, () => find.text('Geometry · 41 · Weak')),
      (
        'legend_row',
        360,
        () => find.byKey(const ValueKey('radar-legend-Geometry')),
      ),
    ]) {
      testWidgets('ANL-01b: ${name}_is_a_button', (tester) async {
        final semantics = tester.ensureSemantics();
        await _pump(tester, _overview(domains: _fourDomains), width: width);

        expect(
          tester.getSemantics(finder()),
          matchesSemantics(
            label: 'Geometry · 41 · Weak',
            textDirection: TextDirection.ltr,
            isButton: true,
            hasTapAction: true,
          ),
        );
        semantics.dispose();
      });
    }

    testWidgets('ANL-01b: two_domains_fall_back_to_bars', (tester) async {
      await _pump(
        tester,
        _overview(domains: skillsOverviewFixture.domains),
      );

      expect(find.byType(DomainBars), findsOneWidget);
      expect(find.text('Algebra · 62 · Building'), findsOneWidget);
      expect(find.text('Geometry · Not started'), findsOneWidget);
    });

    testWidgets('ANL-01b: bars_offer_start_next_for_an_unstarted_domain', (
      tester,
    ) async {
      await _pump(
        tester,
        _overview(domains: skillsOverviewFixture.domains),
        height: 600,
      );

      final chip = find.byKey(const ValueKey('radar-chip-focus'));
      expect(
        find.descendant(of: chip, matching: find.text('Start next: Geometry')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: chip, matching: find.byIcon(AppIcons.play)),
        findsOneWidget,
      );
      expect(find.textContaining('Focus next'), findsNothing);

      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(_scrollOffset(tester), greaterThan(0));
      expect(find.text('topic:t2'), findsNothing);
    });

    testWidgets('ANL-01b: focus_next_wins_over_start_next', (tester) async {
      await _pump(tester, _overview(domains: _fourDomains));

      expect(find.textContaining('Start next'), findsNothing);
      expect(find.text('Focus next: Geometry'), findsOneWidget);
    });

    testWidgets('ANL-01b: no_domains_hides_the_card', (tester) async {
      await _pump(tester, _overview());

      expect(find.byType(DomainRadarCard), findsNothing);
      expect(find.text('Domain mastery'), findsNothing);
    });

    testWidgets('ANL-01b: radar_sits_right_after_the_header', (tester) async {
      await _pump(tester, _overview(domains: _fourDomains));

      final radar = tester.getTopLeft(find.text('Domain mastery')).dy;
      final summary = tester
          .getTopLeft(find.text('12 of 40 questions solved'))
          .dy;
      expect(radar, lessThan(summary));
    });

    testWidgets('ANL-01b: tapping_a_legend_row_scrolls_to_the_domain', (
      tester,
    ) async {
      await _pump(tester, _overview(domains: _fourDomains), height: 600);
      expect(_scrollOffset(tester), 0);

      await tester.tap(find.byKey(const ValueKey('radar-legend-Geometry')));
      await tester.pumpAndSettle();

      expect(_scrollOffset(tester), greaterThan(0));
      expect(tester.getTopLeft(find.text('Geometry').last).dy, lessThan(600));
    });

    testWidgets('ANL-01b: tapping_an_axis_label_scrolls_to_the_domain', (
      tester,
    ) async {
      await _pump(
        tester,
        _overview(domains: _fourDomains),
        width: 1280,
        height: 600,
      );
      expect(_scrollOffset(tester), 0);

      await tester.tap(find.text('Geometry · 41 · Weak'));
      await tester.pumpAndSettle();

      expect(_scrollOffset(tester), greaterThan(0));
      expect(
        tester.getTopLeft(find.text('Geometry')).dy,
        lessThan(600),
      );
    });

    testWidgets('ANL-01b: focus_chip_opens_the_weak_skill_topic', (
      tester,
    ) async {
      const domains = [
        DomainMastery(
          domain: 'Algebra',
          mean: 30,
          band: MasteryBand.weak,
          practised: 2,
          total: 2,
        ),
        DomainMastery(
          domain: 'Geometry',
          mean: 70,
          band: MasteryBand.building,
          practised: 1,
          total: 1,
        ),
        DomainMastery(
          domain: 'Data',
          mean: 50,
          band: MasteryBand.building,
          practised: 1,
          total: 1,
        ),
      ];
      await _pump(tester, _overview(domains: domains));

      await tester.tap(find.byKey(const ValueKey('radar-chip-focus')));
      await tester.pumpAndSettle();

      expect(find.text('topic:t2'), findsOneWidget);
    });

    testWidgets('ANL-01b: focus_chip_scrolls_when_no_weak_skill_in_domain', (
      tester,
    ) async {
      await _pump(tester, _overview(domains: _fourDomains), height: 600);
      final chip = find.byKey(const ValueKey('radar-chip-focus'));
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      final before = _scrollOffset(tester);

      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(find.text('topic:t2'), findsNothing);
      expect(_scrollOffset(tester), greaterThan(before));
    });

    for (final (name, textScale) in [('1x', 1.0), ('2x', 2.0)]) {
      testWidgets('ANL-01b: legend_stays_inside_360_$name', (tester) async {
        await _pump(
          tester,
          _overview(domains: _fourDomains),
          reduced: true,
          textScale: textScale,
        );

        expect(tester.takeException(), isNull);
        for (final domain in ['Algebra', 'Geometry', 'Data', 'Advanced Math']) {
          final rect = tester.getRect(
            find.byKey(ValueKey('radar-legend-$domain')),
          );
          expect(rect.left, greaterThanOrEqualTo(0), reason: domain);
          expect(rect.right, lessThanOrEqualTo(360), reason: domain);
        }
      });
    }

    testWidgets('ANL-01b: wide_labels_are_not_truncated_at_420', (
      tester,
    ) async {
      await _pump(
        tester,
        _overview(
          domains: [
            ..._fourDomains.take(3),
            const DomainMastery(
              domain: 'Problem-Solving and Data Analysis',
              mean: null,
              band: MasteryBand.thin,
              practised: 0,
              total: 2,
            ),
          ],
        ),
        width: 420 + 32 + 32,
      );

      final label = tester.renderObject<RenderParagraph>(
        find.text('Problem-Solving and Data Analysis · Not started'),
      );
      expect(tester.takeException(), isNull);
      expect(label.didExceedMaxLines, isFalse);
    });

    testWidgets('ANL-01b: radar_works_with_three_domains_at_1280', (
      tester,
    ) async {
      await _pump(
        tester,
        _overview(domains: _fourDomains.take(3).toList()),
        width: 1280,
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(DomainBars), findsNothing);
      expect(find.text('Algebra · 78 · Strong'), findsOneWidget);
    });
  });

  group('ANL-01b: trend upgrade', () {
    testWidgets('ANL-01b: delta_up_has_icon_and_word', (tester) async {
      await _pump(tester, _overview());

      final delta = find.byKey(const ValueKey('trend-delta'));
      expect(
        find.descendant(of: delta, matching: find.text('+8 this week')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: delta, matching: find.byIcon(AppIcons.moveUp)),
        findsOneWidget,
      );
    });

    testWidgets('ANL-01b: delta_down_has_icon_and_word', (tester) async {
      await _pump(
        tester,
        _overview(
          trend: [
            TrendPoint(weekStart: DateTime.utc(2026, 10, 12), mastery: 60),
            TrendPoint(weekStart: DateTime.utc(2026, 10, 19), mastery: 57),
          ],
        ),
      );

      final delta = find.byKey(const ValueKey('trend-delta'));
      expect(
        find.descendant(of: delta, matching: find.text('−3 this week')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: delta, matching: find.byIcon(AppIcons.moveDown)),
        findsOneWidget,
      );
    });

    testWidgets('ANL-01b: delta_flat_says_no_change', (tester) async {
      await _pump(
        tester,
        _overview(
          trend: [
            TrendPoint(weekStart: DateTime.utc(2026, 10, 12), mastery: 57),
            TrendPoint(weekStart: DateTime.utc(2026, 10, 19), mastery: 57),
          ],
        ),
      );

      final delta = find.byKey(const ValueKey('trend-delta'));
      expect(
        find.descendant(of: delta, matching: find.text('No change')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: delta, matching: find.byIcon(AppIcons.trendFlat)),
        findsOneWidget,
      );
    });

    testWidgets('ANL-01b: delta_across_a_missing_week_names_the_date', (
      tester,
    ) async {
      await _pump(
        tester,
        _overview(
          trend: [
            TrendPoint(weekStart: DateTime.utc(2026, 10, 5), mastery: 50),
            TrendPoint(weekStart: DateTime.utc(2026, 10, 19), mastery: 57),
          ],
        ),
      );

      final delta = find.byKey(const ValueKey('trend-delta'));
      expect(
        find.descendant(of: delta, matching: find.text('+7 since Oct 5')),
        findsOneWidget,
      );
      expect(find.textContaining('this week'), findsNothing);
    });

    for (final strongAt in [null, 0, 101]) {
      testWidgets('ANL-01b: trend_builds_with_strong_at_$strongAt', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: MasteryTrendChart(
                points: skillsOverviewFixture.trend,
                strongAt: strongAt?.toDouble(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('ANL-01b: no_delta_without_a_trend', (tester) async {
      await _pump(tester, _overview(trend: const []));

      expect(find.byKey(const ValueKey('trend-delta')), findsNothing);
    });

    testWidgets('ANL-01b: trend_chart_still_builds_without_strong_at', (
      tester,
    ) async {
      final overview = SkillsOverview(
        summary: const SkillsSummary(
          solved: 1,
          total: 2,
          gradedAnswers: 20,
          trendMinAnswers: 10,
        ),
        skills: const [],
        weak: const [],
        trend: skillsOverviewFixture.trend,
        topics: const [],
      );
      await _pump(tester, overview);

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('mastery-trend-chart')),
        findsOneWidget,
      );
    });
  });

  group('ANL-01b: skill rows', () {
    testWidgets('ANL-01b: sparkline_shows_with_two_points', (tester) async {
      await _pump(tester, _overview());

      expect(find.byType(SkillSparkline), findsOneWidget);
    });

    testWidgets('ANL-01b: sparkline_hidden_with_fewer_than_two_points', (
      tester,
    ) async {
      await _pump(
        tester,
        _overview(
          skills: [
            SkillMastery(
              code: 'A',
              name: 'Ratios',
              domain: 'Algebra',
              mastery: 60,
              attempts: 8,
              band: MasteryBand.building,
              accuracy: 60,
              history: [
                TrendPoint(weekStart: DateTime.utc(2026, 10, 19), mastery: 60),
              ],
            ),
          ],
        ),
      );

      expect(find.byType(SkillSparkline), findsNothing);
    });

    testWidgets('ANL-01b: accuracy_line_shows_when_there_are_attempts', (
      tester,
    ) async {
      await _pump(tester, _overview());

      expect(find.text('82% correct · 1m 12s avg'), findsOneWidget);
      expect(find.text('50% correct · 45s avg'), findsOneWidget);
    });

    testWidgets('ANL-01b: accuracy_line_hidden_without_attempts', (
      tester,
    ) async {
      await _pump(
        tester,
        _overview(
          skills: const [
            SkillMastery(
              code: 'A',
              name: 'Ratios',
              domain: 'Algebra',
              mastery: null,
              attempts: 0,
              band: MasteryBand.thin,
              accuracy: 50,
            ),
          ],
        ),
      );

      expect(find.textContaining('correct'), findsNothing);
    });

    testWidgets('ANL-01b: sparkline_sits_beside_the_bar_when_wide', (
      tester,
    ) async {
      await _pump(tester, _overview(), width: 1280);

      final spark = tester.getRect(find.byType(SkillSparkline));
      final bar = tester.getRect(
        find.descendant(
          of: find.byKey(const ValueKey('ALG.LIN')),
          matching: find.byType(GrowingBar),
        ),
      );
      expect(spark.size, const Size(56, 20));
      expect(spark.top, lessThan(bar.bottom));
      expect(spark.left, greaterThan(bar.left));
    });

    testWidgets('ANL-01b: sparkline_joins_the_chip_row_at_360', (tester) async {
      await _pump(tester, _overview());

      final row = find.byKey(const ValueKey('ALG.LIN'));
      final bar = tester.getRect(
        find.descendant(of: row, matching: find.byType(GrowingBar)),
      );
      final spark = tester.getRect(
        find.descendant(of: row, matching: find.byType(SkillSparkline)),
      );
      final wrap = find.descendant(of: row, matching: find.byType(Wrap));
      expect(spark.top, greaterThanOrEqualTo(bar.bottom));
      expect(
        find.descendant(of: wrap, matching: find.byType(SkillSparkline)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: wrap, matching: find.byType(MasteryBandChip)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: wrap,
          matching: find.text('82% correct · 1m 12s avg'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('ANL-01b: sparkline_stays_out_of_the_wrap_when_wide', (
      tester,
    ) async {
      await _pump(tester, _overview(), width: 1280);

      final row = find.byKey(const ValueKey('ALG.LIN'));
      expect(
        find.descendant(
          of: find.descendant(of: row, matching: find.byType(Wrap)),
          matching: find.byType(SkillSparkline),
        ),
        findsNothing,
      );
    });

    for (final width in [360.0, 1280.0]) {
      testWidgets('ANL-01b: sparkline_up_delta_has_icon_and_number_$width', (
        tester,
      ) async {
        await _pump(tester, _overview(), width: width);

        final mini = find.byKey(const ValueKey('skill-trend-mini'));
        expect(mini, findsOneWidget);
        expect(
          find.descendant(of: mini, matching: find.text('12')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: mini, matching: find.byIcon(AppIcons.moveUp)),
          findsOneWidget,
        );
      });
    }

    testWidgets('ANL-01b: sparkline_down_and_flat_delta_icons', (tester) async {
      SkillMastery skill(String code, double from, double to) => SkillMastery(
        code: code,
        name: code,
        domain: 'Algebra',
        mastery: to,
        attempts: 8,
        band: MasteryBand.building,
        history: [
          TrendPoint(weekStart: DateTime.utc(2026, 10, 12), mastery: from),
          TrendPoint(weekStart: DateTime.utc(2026, 10, 19), mastery: to),
        ],
      );
      await _pump(
        tester,
        _overview(skills: [skill('DOWN', 60, 55), skill('FLAT', 50, 50)]),
      );

      final down = find.descendant(
        of: find.byKey(const ValueKey('DOWN')),
        matching: find.byKey(const ValueKey('skill-trend-mini')),
      );
      final flat = find.descendant(
        of: find.byKey(const ValueKey('FLAT')),
        matching: find.byKey(const ValueKey('skill-trend-mini')),
      );
      expect(
        find.descendant(of: down, matching: find.text('5')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: down, matching: find.byIcon(AppIcons.moveDown)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: flat, matching: find.text('0')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: flat, matching: find.byIcon(AppIcons.trendFlat)),
        findsOneWidget,
      );
    });

    testWidgets('ANL-01b: row_label_announces_the_sparkline_change', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _overview());

      expect(
        find.bySemanticsLabel(
          'Linear equations, 83 of 100, Strong, 82% correct · 1m 12s avg, '
          'up 12 points since Oct 12',
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });
  });
}
