@Tags(['golden'])
library;

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/features/teacher/course_builder/presentation/cubit/course_builder_cubit.dart';
import 'package:sat_east_client/features/teacher/course_builder/presentation/screens/course_builder_screen.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_bank_cubit.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_editor_cubit.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/screens/question_bank_screen.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/screens/question_editor_screen.dart';
import 'package:sat_east_client/features/teacher/review/presentation/screens/review_queue_screen.dart';
import 'package:sat_east_client/features/teacher/settings/presentation/cubit/teacher_settings_cubit.dart';
import 'package:sat_east_client/features/teacher/settings/presentation/screens/teacher_settings_screen.dart';
import 'package:sat_east_client/features/teacher/shell/teacher_shell.dart';

import '../../../features/teacher/course_builder/builder_fixtures.dart';
import '../../../features/teacher/questions/bank_fixtures.dart';
import '../../../features/teacher/questions/editor_fixtures.dart';
import '../../../features/teacher/review/review_fixtures.dart';
import '../../../features/teacher/settings/settings_fixtures.dart';
import '../feature_golden_harness.dart';

void main() {
  setUp(
    () => registerReviewFakes(
      repository: FakeReviewRepository()..reportsValue = openReports,
    ),
  );
  tearDown(unregisterReviewFakes);
  for (final brightness in Brightness.values) {
    for (final surface in ['builder', 'review', 'settings', 'bank', 'editor']) {
      final widths = surface == 'builder' || surface == 'bank'
          ? [360.0, 1280.0]
          : [1280.0];
      for (final width in widths) {
        final name = 'teacher_${surface}_${brightness.name}_${width.toInt()}';
        testWidgets('ADM-01: golden $name', (tester) async {
          late final Widget body;
          late final String location;
          switch (surface) {
            case 'builder':
              final cubit = CourseBuilderCubit(FakeBuilderRepository());
              addTearDown(cubit.close);
              await cubit.load('c1');
              body = BlocProvider.value(
                value: cubit,
                child: const CourseBuilderView(courseId: 'c1'),
              );
              location = '/teacher/courses/c1';
            case 'review':
              body = const ReviewQueueScreen();
              location = '/teacher/review';
            case 'settings':
              final cubit = TeacherSettingsCubit(
                FakeTeacherSettingsRepository(),
              );
              addTearDown(cubit.close);
              await cubit.load();
              cubit.edit('pass_mark', 80);
              body = BlocProvider.value(
                value: cubit,
                child: const TeacherSettingsView(),
              );
              location = '/teacher/settings';
            case 'bank':
              final cubit = QuestionBankCubit(
                FakeBankRepository(),
                schedule: FakeBankScheduler().schedule,
              );
              addTearDown(cubit.close);
              await cubit.load();
              body = BlocProvider.value(
                value: cubit,
                child: const QuestionBankView(),
              );
              location = '/teacher/questions';
            case 'editor':
              getIt.registerFactory<QuestionEditorCubit>(
                () => QuestionEditorCubit(
                  FakeEditorRepository(),
                  FakeBankRepository(),
                ),
              );
              addTearDown(() => getIt.unregister<QuestionEditorCubit>());
              body = const QuestionEditorScreen(questionId: 'q1');
              location = '/teacher/questions/q1';
          }
          await expectFeatureGolden(
            tester,
            name: '../../baselines/$name',
            width: width,
            height: 1000,
            brightness: brightness,
            location: location,
            child: TeacherShell(child: body),
          );
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        });
      }
    }
  }
}
