import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sat_east_client/core/theme/app_motion.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/teacher/course_builder/domain/entities/node_kind.dart';
import 'package:sat_east_client/features/teacher/course_builder/presentation/cubit/course_builder_cubit.dart';
import 'package:sat_east_client/features/teacher/course_builder/presentation/widgets/builder_siblings.dart';
import 'package:sat_east_client/features/teacher/shell/teacher_animated_rows.dart';
import 'package:sat_east_client/features/teacher/shell/teacher_save_surface.dart';

import 'course_builder/builder_fixtures.dart';

void main() {
  testWidgets('builder blocks row input while removal shifts drag indexes', (
    tester,
  ) async {
    final cubit = CourseBuilderCubit(FakeBuilderRepository());
    addTearDown(cubit.close);
    var taps = 0;
    Future<void> pump(List<String> rows) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: BuilderSiblings<String>(
              kind: NodeKind.unit,
              parentId: 'c1',
              busy: false,
              children: rows,
              idOf: (row) => row,
              row: (row, index, handle, up, down) => Row(
                children: [
                  handle,
                  TextButton(onPressed: () => taps++, child: Text(row)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await pump(['A', 'B']);
    await pump(['B']);
    await tester.tap(find.text('B'), warnIfMissed: false);
    expect(taps, 0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('B'));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
  for (final reduced in [false, true]) {
    testWidgets('teacher rows insert and remove with reduced motion $reduced', (
      tester,
    ) async {
      Future<void> pump(List<String> rows) => tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: Scaffold(
              body: TeacherAnimatedRows(
                children: [
                  for (final row in rows) Text(row, key: ValueKey(row)),
                ],
              ),
            ),
          ),
        ),
      );
      await pump(['A']);
      await pump(['A', 'B']);
      await tester.pump(AppMotion.state);
      expect(find.text('B'), findsOneWidget);
      await pump(['B']);
      if (reduced) {
        expect(find.text('A'), findsNothing);
      } else {
        expect(find.text('A'), findsOneWidget);
        await tester.pumpAndSettle();
        expect(find.text('A'), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('dirty save surface lands immediately with reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: TeacherSaveSurface(child: Text('Save'))),
        ),
      ),
    );
    expect(
      tester
          .widget<FractionalTranslation>(
            find.descendant(
              of: find.byType(TeacherSaveSurface),
              matching: find.byType(FractionalTranslation),
            ),
          )
          .translation,
      Offset.zero,
    );
    expect(tester.takeException(), isNull);
  });
}
