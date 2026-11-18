@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/mock/presentation/cubit/mock_hub_cubit.dart';
import 'package:sat_east_client/features/mock/presentation/screens/mock_hub_screen.dart';
import 'package:sat_east_client/features/mock/presentation/screens/mock_pre_exam_screen.dart';

import '../../features/mock/mock_fakes.dart';
import 'feature_golden_harness.dart';

Future<MockHubCubit> _loaded(
  WidgetTester tester,
  FakeMockRepository repo,
) async {
  final cubit = MockHubCubit(repo);
  addTearDown(cubit.close);
  await tester.runAsync(cubit.load);
  return cubit;
}

void main() {
  for (final width in [360.0, 1280.0]) {
    for (final brightness in Brightness.values) {
      final suffix = '${brightness.name}_${width.toInt()}';
      testWidgets('MCK-01: golden mock_hub_loaded_$suffix', (tester) async {
        final repo = FakeMockRepository()
          ..hubResult = const Success(MockHubFixtures.allStates);
        final cubit = await _loaded(tester, repo);
        await expectFeatureGolden(
          tester,
          name: 'mock_hub_loaded_$suffix',
          width: width,
          brightness: brightness,
          location: '/mock-exams',
          child: Scaffold(
            body: BlocProvider.value(
              value: cubit,
              child: const MockHubView(),
            ),
          ),
        );
      });
    }

    testWidgets('MCK-01: golden mock_pre_exam_light_${width.toInt()}', (
      tester,
    ) async {
      final cubit = await _loaded(tester, FakeMockRepository());
      await expectFeatureGolden(
        tester,
        name: 'mock_pre_exam_light_${width.toInt()}',
        width: width,
        brightness: Brightness.light,
        location: '/mock-exams/start',
        child: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: const MockPreExamView(),
          ),
        ),
      );
    });
  }
}
