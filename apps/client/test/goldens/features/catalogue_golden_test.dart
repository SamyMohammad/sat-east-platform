@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/catalogue/data/models/catalogue_course_model.dart';
import 'package:sat_east_client/features/catalogue/presentation/cubit/catalogue_cubit.dart';
import 'package:sat_east_client/features/catalogue/presentation/screens/catalogue_screen.dart';

import '../../features/catalogue/catalogue_fixtures.dart';
import 'feature_golden_harness.dart';

void main() {
  for (final width in [360.0, 1280.0]) {
    for (final brightness in Brightness.values) {
      for (final empty in [false, true]) {
        final state = empty ? 'empty' : 'courses';
        final name = 'catalogue_${state}_${brightness.name}_${width.toInt()}';
        testWidgets('PAY-01: golden $name', (tester) async {
          final repository = FakeCatalogueRepository();
          if (!empty) {
            repository.catalogue = Success([
              catalogueCourseFromJson(coursePayload),
              catalogueCourseFromJson({
                ...coursePayload,
                'id': 'c2',
                'code': 'EST',
                'slug': 'est-math',
                'title': 'EST Math',
              }),
            ]);
          }
          final cubit = CatalogueCubit(repository);
          addTearDown(cubit.close);
          await cubit.load();
          await expectFeatureGolden(
            tester,
            name: name,
            width: width,
            height: 1200,
            brightness: brightness,
            location: '/catalogue',
            child: BlocProvider<CatalogueCubit>.value(
              value: cubit,
              child: const CatalogueView(enablePurchase: true),
            ),
          );
        });
      }
    }
  }
}
