@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/features/course_map/presentation/cubit/course_map_cubit.dart';
import 'package:sat_east_client/features/course_map/presentation/cubit/course_map_state.dart';
import 'package:sat_east_client/features/course_map/presentation/screens/course_map_screen.dart';

import '../../features/course_map/course_map_fixtures.dart';
import 'feature_golden_harness.dart';

void main() {
  for (final width in [360.0, 1280.0]) {
    for (final brightness in Brightness.values) {
      for (final unlocked in [false, true]) {
        final state = unlocked ? 'unlocked' : 'loaded';
        final name = 'course_map_${state}_${brightness.name}_${width.toInt()}';
        testWidgets('L-1: golden $name', (tester) async {
          final cubit = courseMapCubit(
            CourseMapLoaded(
              courseMapFixture(continueTopic: continueMapTopic),
              justUnlocked: unlocked ? {openMapTopic.id} : const {},
            ),
          );
          await expectFeatureGolden(
            tester,
            name: name,
            width: width,
            brightness: brightness,
            location: '/courses',
            child: BlocProvider<CourseMapCubit>.value(
              value: cubit,
              child: const Scaffold(body: CourseMapView()),
            ),
          );
          if (unlocked) verify(cubit.acknowledgeUnlock).called(1);
          expect(find.byKey(const ValueKey('unlock-lock')), findsNothing);
        });
      }
    }
  }
}
