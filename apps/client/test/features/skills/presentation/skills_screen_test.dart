import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/skills/domain/entities/skills_overview.dart';
import 'package:sat_east_client/features/skills/presentation/cubit/skills_cubit.dart';
import 'package:sat_east_client/features/skills/presentation/cubit/skills_state.dart';
import 'package:sat_east_client/features/skills/presentation/screens/skills_screen.dart';
import 'package:sat_east_client/features/skills/presentation/widgets/mastery_band_chip.dart';
import 'package:sat_east_client/shared/widgets/app_skeleton.dart';
import 'package:sat_east_client/shared/widgets/growing_bar.dart';

import '../skills_fixtures.dart';

class FakeSkillsCubit extends MockCubit<SkillsState> implements SkillsCubit {}

SkillsOverview _overview({
  List<SkillMastery>? skills,
  List<TrendPoint>? trend,
  SkillsSummary? summary,
}) => SkillsOverview(
  summary: summary ?? skillsOverviewFixture.summary,
  skills: skills ?? skillsOverviewFixture.skills,
  weak: skillsOverviewFixture.weak,
  trend: trend ?? skillsOverviewFixture.trend,
  topics: skillsOverviewFixture.topics,
);

Future<FakeSkillsCubit> _pump(
  WidgetTester tester,
  SkillsState state, {
  double width = 360,
  double height = 3000,
  bool reduced = false,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final cubit = FakeSkillsCubit();
  whenListen(cubit, const Stream<SkillsState>.empty(), initialState: state);
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
      GoRoute(
        path: '/activate',
        builder: (_, _) => const Scaffold(body: Text('activation form')),
      ),
      GoRoute(
        path: '/catalogue',
        builder: (_, _) => const Scaffold(body: Text('catalogue page')),
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
  return cubit;
}

void main() {
  group('ANL-01: SkillsView', () {
    testWidgets('ANL-01: loading shows the skeleton', (tester) async {
      await _pump(tester, const SkillsLoading());

      expect(find.byType(AppSkeleton), findsNWidgets(5));
    });

    testWidgets('ANL-01: summary_shows_solved_and_answers', (tester) async {
      await _pump(tester, SkillsLoaded(skillsOverviewFixture, 'c1'));

      expect(find.text('Skills'), findsWidgets);
      expect(find.text('12 of 40 questions solved'), findsOneWidget);
      expect(find.text('31 answers so far'), findsOneWidget);
    });

    testWidgets('ANL-01: weak_first_with_practise_this', (tester) async {
      await _pump(tester, SkillsLoaded(skillsOverviewFixture, 'c1'));

      final weakTop = tester.getTopLeft(find.text('Weakest skills')).dy;
      final allTop = tester.getTopLeft(find.text('All skills')).dy;
      expect(weakTop, lessThan(allTop));

      final practise = find.text('Practise this');
      await tester.ensureVisible(practise);
      await tester.tap(practise);
      await tester.pumpAndSettle();

      expect(find.text('topic:t2'), findsOneWidget);
    });

    testWidgets('ANL-01: no_weak_skill_shows_thin_copy', (tester) async {
      final overview = SkillsOverview(
        summary: skillsOverviewFixture.summary,
        skills: skillsOverviewFixture.skills,
        weak: const [],
        trend: skillsOverviewFixture.trend,
        topics: skillsOverviewFixture.topics,
      );
      await _pump(tester, SkillsLoaded(overview, 'c1'));

      expect(
        find.text('Not enough answers to name a weak skill yet.'),
        findsOneWidget,
      );
      expect(find.text('Practise this'), findsNothing);
    });

    testWidgets('ANL-01: band_shows_icon_and_word', (tester) async {
      await _pump(tester, SkillsLoaded(skillsOverviewFixture, 'c1'));

      for (final (word, icon) in [
        ('Weak', AppIcons.masteryWeak),
        ('Strong', AppIcons.masteryStrong),
        ('Not enough answers yet', AppIcons.masteryThin),
      ]) {
        final chip = find.byWidgetPredicate(
          (widget) =>
              widget is MasteryBandChip &&
              switch (widget.band) {
                MasteryBand.weak => word == 'Weak',
                MasteryBand.strong => word == 'Strong',
                MasteryBand.thin => word == 'Not enough answers yet',
                MasteryBand.building => false,
              },
        );
        expect(chip, findsWidgets, reason: word);
        expect(
          find.descendant(of: chip.first, matching: find.text(word)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: chip.first, matching: find.byIcon(icon)),
          findsOneWidget,
          reason: word,
        );
      }
    });

    testWidgets('ANL-01: bands_use_their_semantic_colours', (tester) async {
      await _pump(tester, SkillsLoaded(skillsOverviewFixture, 'c1'));
      for (final band in MasteryBand.values) {
        final colors = tester.element(find.byType(SkillsView)).appColors;
        expect(band.color(colors), switch (band) {
          MasteryBand.weak => colors.incorrect,
          MasteryBand.building => colors.warning,
          MasteryBand.strong => colors.correct,
          MasteryBand.thin => colors.inkTertiary,
        });
      }
    });

    testWidgets('ANL-01: mastery_row_announces_name_value_and_band', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, SkillsLoaded(skillsOverviewFixture, 'c1'));
      expect(
        find.bySemanticsLabel('Linear equations, 83 of 100, Strong'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('ANL-01: building_band_shows_icon_and_word', (tester) async {
      final overview = _overview(
        skills: const [
          SkillMastery(
            code: 'B',
            name: 'Ratios',
            domain: 'Algebra',
            mastery: 60,
            attempts: 8,
            band: MasteryBand.building,
          ),
        ],
      );
      await _pump(tester, SkillsLoaded(overview, 'c1'));

      expect(find.text('Building'), findsOneWidget);
      expect(find.byIcon(AppIcons.masteryBuilding), findsOneWidget);
    });

    testWidgets('ANL-01: skills_grouped_by_domain', (tester) async {
      await _pump(tester, SkillsLoaded(skillsOverviewFixture, 'c1'));

      expect(find.text('Algebra'), findsWidgets);
      expect(find.text('Geometry'), findsOneWidget);
      expect(find.text('Linear equations'), findsWidgets);
      expect(find.text('Circles'), findsOneWidget);
      expect(find.text('82'), findsNothing);
      expect(find.text('83'), findsOneWidget);
    });

    testWidgets('ANL-01: topics_show_solved_and_level', (tester) async {
      await _pump(tester, SkillsLoaded(skillsOverviewFixture, 'c1'));

      expect(find.text('5 of 10 solved'), findsOneWidget);
      expect(find.text('1 of 8 solved'), findsOneWidget);
    });

    testWidgets('ANL-01: no_skills_state', (tester) async {
      await _pump(
        tester,
        SkillsLoaded(_overview(skills: const [], trend: const []), 'c1'),
      );

      expect(
        find.text('Skills appear once questions are tagged.'),
        findsOneWidget,
      );
      expect(find.text('12 of 40 questions solved'), findsOneWidget);
      expect(find.text('Linear equations'), findsWidgets);
    });

    testWidgets('ANL-01: trend_chart_shows_labels', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, SkillsLoaded(skillsOverviewFixture, 'c1'));

      expect(find.byKey(const ValueKey('mastery-trend-chart')), findsOneWidget);
      expect(find.text('Weekly trend'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Weekly mastery.*57')),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('ANL-01: trend_single_point_is_thin', (tester) async {
      await _pump(
        tester,
        SkillsLoaded(
          _overview(
            trend: [
              TrendPoint(weekStart: DateTime.utc(2026, 10, 19), mastery: 57),
            ],
          ),
          'c1',
        ),
      );

      expect(find.byKey(const ValueKey('mastery-trend-chart')), findsNothing);
      expect(find.text('Keep practising to see a trend.'), findsOneWidget);
    });

    testWidgets('ANL-01: trend_thin_counts_missing_answers', (tester) async {
      await _pump(
        tester,
        SkillsLoaded(
          _overview(
            trend: const [],
            summary: const SkillsSummary(
              solved: 1,
              total: 40,
              gradedAnswers: 6,
              trendMinAnswers: 10,
            ),
          ),
          'c1',
        ),
      );

      expect(find.byKey(const ValueKey('mastery-trend-chart')), findsNothing);
      expect(
        find.text('Answer 4 more questions to see a trend.'),
        findsOneWidget,
      );
    });

    testWidgets('ANL-01: empty_state_copy', (tester) async {
      await _pump(tester, const SkillsEmpty());

      expect(
        find.text(
          'Answer a few practice questions and your skills show up '
          'here.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Go to your course'));
      await tester.pumpAndSettle();

      expect(find.text('courses page'), findsOneWidget);
    });

    testWidgets('ANL-01: access_expired_copy', (tester) async {
      final cubit = await _pump(
        tester,
        const SkillsFailed(AppError(ErrorCodes.accessExpired)),
      );

      expect(find.text('Access ended'), findsOneWidget);
      expect(
        find.text('Your access has ended. Contact your teacher.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Retry'));
      verify(cubit.retry).called(1);
    });

    testWidgets('ANL-01: not_enrolled_offers_activation', (tester) async {
      await _pump(
        tester,
        const SkillsFailed(AppError(ErrorCodes.notEnrolled)),
      );

      expect(find.text('No course yet'), findsOneWidget);
      await tester.tap(find.text('Enter activation code'));
      await tester.pumpAndSettle();
      expect(find.text('activation form'), findsOneWidget);
    });

    testWidgets('ANL-01: network_error_retries', (tester) async {
      final cubit = await _pump(
        tester,
        const SkillsFailed(AppError(ErrorCodes.network)),
      );

      expect(find.text("Couldn't load your skills"), findsOneWidget);
      expect(find.text('Check your connection and try again.'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      verify(cubit.retry).called(1);
    });

    testWidgets('ANL-01: reduced_motion_bars_static', (tester) async {
      await _pump(
        tester,
        SkillsLoaded(skillsOverviewFixture, 'c1'),
        reduced: true,
      );

      final fills = tester
          .widgetList<FractionallySizedBox>(
            find.byKey(const ValueKey('growing-bar-fill')),
          )
          .map((fill) => fill.widthFactor)
          .toList();
      expect(fills, contains(.825));
      expect(fills, contains(.41));
    });

    testWidgets('ANL-01: bars_grow_when_motion_is_on', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: GrowingBar(value: .8, color: Colors.blue, index: 3),
          ),
        ),
      );
      double factor() => tester
          .widget<FractionallySizedBox>(
            find.byKey(const ValueKey('growing-bar-fill')),
          )
          .widthFactor!;

      expect(factor(), 0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(factor(), lessThan(.8));
      await tester.pumpAndSettle();
      expect(factor(), closeTo(.8, 1e-9));
    });

    for (final state in <(String, SkillsState)>[
      ('loaded', SkillsLoaded(skillsOverviewFixture, 'c1')),
      ('empty', const SkillsEmpty()),
      ('failed', const SkillsFailed(AppError(ErrorCodes.network))),
    ]) {
      testWidgets('ANL-01: no_overflow_360_text2x ${state.$1}', (
        tester,
      ) async {
        await _pump(tester, state.$2, reduced: true, textScale: 2);

        expect(tester.takeException(), isNull);
      });
    }
  });
}
