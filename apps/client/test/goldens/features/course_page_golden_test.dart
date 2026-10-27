@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_state.dart';
import 'package:sat_east_client/features/catalogue/data/models/course_page_model.dart';
import 'package:sat_east_client/features/catalogue/presentation/cubit/course_page_cubit.dart';
import 'package:sat_east_client/features/catalogue/presentation/screens/course_page_screen.dart';

import '../../features/auth/presentation/screens/auth_screen_harness.dart'
    as auth;
import '../../features/catalogue/catalogue_fixtures.dart';
import 'feature_golden_harness.dart';

void main() {
  for (final width in [360.0, 1280.0]) {
    for (final brightness in Brightness.values) {
      final name = 'course_page_${brightness.name}_${width.toInt()}';
      testWidgets('PAY-01: golden $name', (tester) async {
        final repository = FakeCatalogueRepository()
          ..page = Success(coursePageFromJson(pagePayload));
        final cubit = CoursePageCubit(repository);
        addTearDown(cubit.close);
        await cubit.load('sat-math');
        await expectFeatureGolden(
          tester,
          name: name,
          width: width,
          height: 1200,
          brightness: brightness,
          location: '/catalogue/sat-math',
          child: MultiBlocProvider(
            providers: [
              BlocProvider<AuthCubit>.value(
                value: auth.mockCubit(const AuthSignedOut()),
              ),
              BlocProvider<CoursePageCubit>.value(value: cubit),
            ],
            child: const CoursePageView(enablePurchase: true),
          ),
        );
      });
    }
  }
}
