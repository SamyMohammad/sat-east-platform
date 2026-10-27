import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/teacher/course_builder/presentation/cubit/course_builder_cubit.dart';
import 'package:sat_east_client/features/teacher/course_builder/presentation/screens/course_builder_screen.dart';
import 'package:sat_east_client/features/teacher/course_builder/presentation/widgets/builder_title_dialog.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_bank_cubit.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_editor_cubit.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/screens/question_bank_screen.dart';
import 'package:sat_east_client/features/teacher/shell/teacher_bottom_navigation.dart';
import 'package:sat_east_client/features/teacher/shell/teacher_shell.dart';
import 'package:sat_east_client/shared/widgets/app_dialog.dart';

import 'course_builder/builder_fixtures.dart';
import 'questions/bank_fixtures.dart';
import 'questions/editor_fixtures.dart';
import 'questions/presentation/question_editor_screen_test.dart'
    show pumpEditor;
import 'review/review_fixtures.dart';

void main() {
  setUp(registerReviewFakes);
  tearDown(unregisterReviewFakes);

  testWidgets('teacher_shell_reduced_motion', (tester) async {
    await _pump(tester, const TeacherShell(child: Text('Body')));
    expect(find.byType(TeacherBottomNavigation), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected Review retains its count badge', (tester) async {
    await _pump(
      tester,
      Scaffold(
        bottomNavigationBar: TeacherBottomNavigation(
          path: '/teacher/review',
          onSelected: (_) {},
          reviewBadge: const Text('7'),
        ),
      ),
    );
    expect(find.text('7'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('builder title uses AppDialog and preserves submission', (
    tester,
  ) async {
    await _pump(
      tester,
      const Scaffold(body: BuilderTitleDialog(label: 'Add unit')),
    );
    expect(find.byType(AppDialog), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Algebra');
    expect(find.text('Algebra'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('builder has no overflow at 360 and 2x text', (tester) async {
    final cubit = CourseBuilderCubit(FakeBuilderRepository());
    addTearDown(cubit.close);
    await cubit.load('c1');
    await _pump(
      tester,
      TeacherShell(
        child: BlocProvider.value(
          value: cubit,
          child: const CourseBuilderView(courseId: 'c1'),
        ),
      ),
    );
    expect(find.text('Linear equations'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bank has no overflow at 360 and 2x text', (tester) async {
    final cubit = QuestionBankCubit(
      FakeBankRepository(),
      schedule: FakeBankScheduler().schedule,
    );
    addTearDown(cubit.close);
    await cubit.load();
    await _pump(
      tester,
      TeacherShell(
        child: BlocProvider.value(
          value: cubit,
          child: const QuestionBankView(),
        ),
      ),
    );
    expect(find.text('Question bank'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editor has no overflow at 360 and 2x text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final cubit = QuestionEditorCubit(
      FakeEditorRepository(),
      FakeBankRepository(),
    );
    await pumpEditor(tester, cubit, width: 360);
    expect(find.text('Edit question'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 1200);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(2),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}
