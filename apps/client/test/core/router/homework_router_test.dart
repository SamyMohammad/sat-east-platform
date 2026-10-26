import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/attempt_review/data/models/attempt_review_model.dart';
import 'package:sat_east_client/features/attempt_review/presentation/cubit/attempt_review_cubit.dart';
import 'package:sat_east_client/features/attempt_review/presentation/cubit/attempt_review_state.dart';
import 'package:sat_east_client/features/homework/presentation/cubit/homework_cubit.dart';
import 'package:sat_east_client/features/homework/presentation/cubit/homework_state.dart';

import '../../features/attempt_review/review_fixture.dart';
import '../../features/homework/homework_fixture.dart';
import 'fake_course_map_cubit.dart';

class _HomeworkCubit extends MockCubit<HomeworkState>
    implements HomeworkCubit {}

class _ReviewCubit extends MockCubit<AttemptReviewState>
    implements AttemptReviewCubit {}

void main() {
  setUp(registerFakeCourseMapCubit);
  tearDown(unregisterFakeCourseMapCubit);
  testWidgets('PRC-02: homework submission opens the shared report route', (
    tester,
  ) async {
    final homework = _HomeworkCubit();
    final review = _ReviewCubit();
    final stream = StreamController<HomeworkState>();
    addTearDown(stream.close);
    whenListen(
      homework,
      stream.stream,
      initialState: const HomeworkRunning(session: homeworkSession),
    );
    when(() => homework.start(any())).thenAnswer((_) async {});
    when(homework.close).thenAnswer((_) async {});
    whenListen(
      review,
      const Stream<AttemptReviewState>.empty(),
      initialState: AttemptReviewLoaded(attemptReviewFromJson(reviewPayload())),
    );
    when(() => review.load(any())).thenAnswer((_) async {});
    when(review.close).thenAnswer((_) async {});
    getIt
      ..registerFactory<HomeworkCubit>(() => homework)
      ..registerFactory<AttemptReviewCubit>(() => review);
    addTearDown(() async {
      await getIt.unregister<HomeworkCubit>();
      await getIt.unregister<AttemptReviewCubit>();
    });
    final router = createRouter(initialLocation: AppRoutes.homework('t1'));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
    });
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
    await tester.pumpAndSettle();
    verify(() => homework.start('t1')).called(1);
    stream.add(const HomeworkSubmitted(homeworkReport));
    await tester.pumpAndSettle();
    // context.replace (same as the quiz result) does not update the reported
    // location, so the test checks the review screen itself.
    verify(() => review.load('hw1')).called(1);
    expect(find.text('14 / 20 \u00b7 70%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
