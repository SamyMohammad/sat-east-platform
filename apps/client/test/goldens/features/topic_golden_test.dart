@Tags(['golden'])
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/features/topic/presentation/cubit/topic_cubit.dart';
import 'package:sat_east_client/features/topic/presentation/cubit/topic_state.dart';
import 'package:sat_east_client/features/topic/presentation/screens/topic_screen.dart';

import '../../core/router/fake_topic_cubit.dart';
import '../../features/topic/topic_fixture.dart';
import 'feature_golden_harness.dart';

void main() {
  for (final width in [360.0, 1280.0]) {
    for (final brightness in Brightness.values) {
      final name = 'topic_${brightness.name}_${width.toInt()}';
      testWidgets('PRC-03: golden $name', (tester) async {
        final cubit = FakeTopicCubit();
        whenListen(
          cubit,
          const Stream<TopicState>.empty(),
          initialState: const TopicLoaded(topicFixture),
        );
        await expectFeatureGolden(
          tester,
          name: name,
          width: width,
          brightness: brightness,
          location: '/courses/topics/t1',
          child: BlocProvider<TopicCubit>.value(
            value: cubit,
            child: const Scaffold(body: TopicView(topicId: 't1')),
          ),
        );
      });
    }
  }
}
