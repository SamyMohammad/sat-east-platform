import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/catalogue/data/models/course_page_model.dart';
import 'package:sat_east_client/features/catalogue/domain/entities/course_page.dart';
import 'package:sat_east_client/features/catalogue/presentation/cubit/course_page_cubit.dart';
import 'package:sat_east_client/features/catalogue/presentation/cubit/course_page_state.dart';

import '../catalogue_fixtures.dart';

void main() {
  late FakeCatalogueRepository repository;
  final data = coursePageFromJson(pagePayload);
  setUp(() {
    repository = FakeCatalogueRepository()..page = Success(data);
  });
  blocTest<CoursePageCubit, CoursePageState>(
    'PAY-01: retry recovers from a failed request',
    build: () => CoursePageCubit(repository),
    act: (cubit) async {
      repository.page = const Failure(AppError('network'));
      await cubit.load('sat-math');
      repository.page = Success(data);
      await cubit.retry();
    },
    expect: () => [
      const CoursePageLoading(),
      const CoursePageFailed(AppError('network')),
      const CoursePageLoading(),
      CoursePageLoaded(data),
    ],
  );
  for (final retry in [false, true]) {
    for (final failure in [false, true]) {
      blocTest<CoursePageCubit, CoursePageState>(
        'PAY-01: $retry retry / $failure failure emits load outcome',
        build: () {
          if (failure) {
            repository.page = const Failure(AppError('network'));
          }
          return CoursePageCubit(repository);
        },
        act: (cubit) async {
          await cubit.load('sat-math');
          if (retry) await cubit.retry();
        },
        expect: () => [
          const CoursePageLoading(),
          if (failure)
            const CoursePageFailed(AppError('network'))
          else
            CoursePageLoaded(data),
          if (retry) ...[
            const CoursePageLoading(),
            if (failure)
              const CoursePageFailed(AppError('network'))
            else
              CoursePageLoaded(data),
          ],
        ],
        verify: (_) => expect(
          repository.slugs,
          retry ? ['sat-math', 'sat-math'] : ['sat-math'],
        ),
      );
    }
  }
  for (final outcome in <Result<CoursePage>>[
    Success(data),
    const Failure(AppError('network')),
  ]) {
    test('PAY-01: closed CoursePage ignores pending $outcome', () async {
      final pending = Completer<Result<CoursePage>>();
      repository.pendingPage = pending.future;
      final cubit = CoursePageCubit(repository);
      final request = cubit.load('sat-math');
      await cubit.close();
      pending.complete(outcome);
      await request;
      expect(cubit.state, const CoursePageLoading());
    });
  }
  test(
    'PAY-01: CoursePage methods after close never call repository',
    () async {
      final cubit = CoursePageCubit(repository);
      await cubit.close();
      await cubit.load('sat-math');
      await cubit.retry();
      expect(repository.slugs, isEmpty);
    },
  );
}
