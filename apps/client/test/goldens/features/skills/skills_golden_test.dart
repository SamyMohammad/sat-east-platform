@Tags(['golden'])
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/skills/domain/entities/skills_overview.dart';
import 'package:sat_east_client/features/skills/presentation/cubit/skills_cubit.dart';
import 'package:sat_east_client/features/skills/presentation/cubit/skills_state.dart';
import 'package:sat_east_client/features/skills/presentation/screens/skills_screen.dart';

import '../../../features/skills/skills_fixtures.dart';
import '../../full_viewport_harness.dart';

class _SkillsCubit extends MockCubit<SkillsState> implements SkillsCubit {}

SkillsOverview _loadedOverview() => SkillsOverview(
  summary: skillsOverviewFixture.summary,
  skills: [
    ...skillsOverviewFixture.skills,
    const SkillMastery(
      code: 'GEO.TRI',
      name: 'Triangles',
      domain: 'Geometry',
      mastery: 62,
      attempts: 8,
      band: MasteryBand.building,
    ),
  ],
  weak: skillsOverviewFixture.weak,
  trend: skillsOverviewFixture.trend,
  topics: skillsOverviewFixture.topics,
);

SkillsOverview _thinOverview() => const SkillsOverview(
  summary: SkillsSummary(
    solved: 1,
    total: 40,
    gradedAnswers: 3,
    trendMinAnswers: 10,
  ),
  skills: [
    SkillMastery(
      code: 'ALG.LIN',
      name: 'Linear equations',
      domain: 'Algebra',
      mastery: null,
      attempts: 3,
      band: MasteryBand.thin,
    ),
  ],
  weak: [],
  trend: [],
  topics: [
    TopicLevel(
      topicId: 't1',
      title: 'Linear equations',
      unitTitle: 'Algebra',
      solved: 1,
      total: 10,
      level: MasteryBand.thin,
    ),
  ],
);

void main() {
  for (final width in [360.0, 1280.0]) {
    for (final brightness in Brightness.values) {
      for (final (stateName, state) in <(String, SkillsState)>[
        ('loaded', SkillsLoaded(_loadedOverview(), 'c1')),
        ('thin', SkillsLoaded(_thinOverview(), 'c1')),
        ('empty', const SkillsEmpty()),
        ('error', const SkillsFailed(AppError(ErrorCodes.accessExpired))),
      ]) {
        final name = 'skills_${stateName}_${brightness.name}_${width.toInt()}';
        testWidgets('ANL-01: golden $name', (tester) async {
          final cubit = _SkillsCubit();
          whenListen(
            cubit,
            const Stream<SkillsState>.empty(),
            initialState: state,
          );
          when(cubit.retry).thenAnswer((_) async {});
          final router = GoRouter(
            initialLocation: '/skills',
            routes: [
              GoRoute(
                path: '/skills',
                builder: (_, _) => BlocProvider<SkillsCubit>.value(
                  value: cubit,
                  child: const Scaffold(body: SkillsView()),
                ),
              ),
            ],
          );
          addTearDown(router.dispose);
          await expectViewportGolden(
            tester,
            name: name,
            width: width,
            height: stateName == 'loaded' ? 1800 : 1000,
            brightness: brightness,
            directory: '../../baselines',
            child: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: Router.withConfig(config: router),
              ),
            ),
          );
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }
}
