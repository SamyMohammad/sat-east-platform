import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/teacher/mock/domain/entities/mock_entities.dart';
import 'package:sat_east_client/features/teacher/mock/domain/usecases/find_sat_course.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/cubit/mock_overview_cubit.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/mock_copy.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/screens/mock_overview_screen.dart';

import '../../course_builder/builder_fixtures.dart';
import '../mock_fakes.dart';
import '../mock_fixtures.dart';

Future<MockOverviewCubit> _pump(
  WidgetTester tester,
  FakeTeacherMockRepository mock, {
  FakeBuilderRepository? courses,
  double width = 1280,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1000);
  addTearDown(tester.view.reset);
  final cubit = MockOverviewCubit(
    mock,
    FindSatCourse(courses ?? FakeBuilderRepository()),
  );
  addTearDown(cubit.close);
  await cubit.load();
  final router = GoRouter(
    initialLocation: AppRoutes.teacherMockExams,
    routes: [
      GoRoute(
        path: AppRoutes.teacherMockExams,
        builder: (_, _) => Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: const MockOverviewView(),
          ),
        ),
      ),
      GoRoute(
        path: '${AppRoutes.teacherMockExams}/:setNo/:formNo',
        builder: (_, state) => Text(
          'Form body ${state.pathParameters['setNo']}/'
          '${state.pathParameters['formNo']}',
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
  await tester.pumpAndSettle();
  return cubit;
}

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Assemble form'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('MCK-03: ready bank shows the ready line', (tester) async {
    await _pump(tester, FakeTeacherMockRepository());
    expect(find.text('Ready to assemble a form'), findsOneWidget);
    expect(find.textContaining('no single SAT domain'), findsNothing);
    expect(find.text('What one form needs'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('MCK-03: shortage lists cells and no_domain', (tester) async {
    final mock = FakeTeacherMockRepository()
      ..overviewResult = Success(shortOverview);
    await _pump(tester, mock);
    expect(find.text('Ready to assemble a form'), findsNothing);
    expect(find.textContaining('Algebra · Hard · SPR'), findsOneWidget);
    expect(find.textContaining('need 4, have 2'), findsOneWidget);
    expect(
      find.text('3 mock questions have no single SAT domain'),
      findsOneWidget,
    );
  });

  testWidgets('MCK-03: need per form is collapsed until tapped', (
    tester,
  ) async {
    await _pump(tester, FakeTeacherMockRepository());
    expect(find.text('66 questions per form'), findsNothing);
    await tester.tap(find.text('What one form needs'));
    await tester.pumpAndSettle();
    expect(find.text('66 questions per form'), findsOneWidget);
  });

  testWidgets('MCK-03: forms list shows status chips and published date', (
    tester,
  ) async {
    await _pump(tester, FakeTeacherMockRepository());
    expect(find.text('Set 1 · Form 1'), findsOneWidget);
    expect(find.text('Set 1 · Form 2'), findsOneWidget);
    expect(find.text('Published'), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);
    expect(find.textContaining('10 Nov 2026'), findsOneWidget);
  });

  testWidgets('MCK-03: tapping a form opens its detail route', (tester) async {
    await _pump(tester, FakeTeacherMockRepository());
    await tester.tap(find.text('Set 1 · Form 2'));
    await tester.pumpAndSettle();
    expect(find.text('Form body 1/2'), findsOneWidget);
  });

  testWidgets('MCK-03: empty forms list shows an empty state', (tester) async {
    final mock = FakeTeacherMockRepository()
      ..overviewResult = const Success(
        MockOverview(
          templateName: 'SAT Math',
          needPerForm: [],
          forms: [],
          missing: [],
          noDomain: 0,
        ),
      );
    await _pump(tester, mock);
    expect(find.text('No forms yet'), findsOneWidget);
  });

  testWidgets('MCK-03: no SAT course shows an empty state, no mock RPC', (
    tester,
  ) async {
    final mock = FakeTeacherMockRepository();
    final courses = FakeBuilderRepository()
      ..courses = Success(
        builderCourses.where((c) => c.code != 'SAT').toList(),
      );
    await _pump(tester, mock, courses: courses);
    expect(find.text('No SAT course yet'), findsOneWidget);
    expect(mock.calls, isEmpty);
  });

  testWidgets('MCK-03: failed load shows retry that reloads', (tester) async {
    final mock = FakeTeacherMockRepository()
      ..overviewResult = const Failure(AppError('internal'));
    await _pump(tester, mock);
    expect(find.text(mockErrorCopy('internal')), findsWidgets);
    mock.overviewResult = Success(readyOverview);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Ready to assemble a form'), findsOneWidget);
  });

  testWidgets('MCK-03: assemble dialog defaults to set 1 with next set', (
    tester,
  ) async {
    await _pump(tester, FakeTeacherMockRepository());
    await _openDialog(tester);
    expect(find.text('Assemble a form'), findsOneWidget);
    final dropdown = tester.widget<DropdownButtonFormField<int>>(
      find.byType(DropdownButtonFormField<int>),
    );
    expect(dropdown.initialValue, 1);
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    expect(find.text('Next set (2)'), findsOneWidget);
  });

  testWidgets('MCK-03: assemble confirm navigates to the new form', (
    tester,
  ) async {
    final mock = FakeTeacherMockRepository();
    await _pump(tester, mock);
    await _openDialog(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Assemble'));
    await tester.pumpAndSettle();
    expect(mock.calls.where((c) => c.$1 == 'assemble').single.$2, ['c1', 1]);
    expect(find.text('Form body 1/3'), findsOneWidget);
  });

  testWidgets('MCK-03: cancelling the dialog does nothing', (tester) async {
    final mock = FakeTeacherMockRepository();
    await _pump(tester, mock);
    await _openDialog(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(mock.calls.where((c) => c.$1 == 'assemble'), isEmpty);
  });

  testWidgets('MCK-03: assemble shortage stays and shows the banner', (
    tester,
  ) async {
    final mock = FakeTeacherMockRepository();
    await _pump(tester, mock);
    mock
      ..assembleResult = const Success(
        Shortage(missing: [parsedShortage], noDomain: 0),
      )
      ..overviewResult = Success(shortOverview);
    await _openDialog(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Assemble'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Form body'), findsNothing);
    expect(find.text(mockShortageBanner), findsOneWidget);
    expect(find.textContaining('Algebra · Hard · SPR'), findsOneWidget);
  });

  test('MCK-03: mockErrorCopy maps server codes', () {
    expect(
      mockErrorCopy('mock_form_published'),
      'This form is already published.',
    );
    expect(
      mockErrorCopy('invalid_input'),
      'This form no longer exists. Refresh the page.',
    );
    expect(mockErrorCopy('forbidden'), isNot(mockErrorCopy('internal')));
  });

  for (final width in [360.0, 1280.0]) {
    testWidgets('MCK-03: overview fits $width', (tester) async {
      final mock = FakeTeacherMockRepository()
        ..overviewResult = Success(shortOverview);
      await _pump(tester, mock, width: width);
      expect(tester.takeException(), isNull);
    });
  }
}
