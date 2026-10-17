import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/course_map/domain/entities/course_map.dart';
import 'package:sat_east_client/features/course_map/domain/repositories/course_map_repository.dart';
import 'package:sat_east_client/features/course_map/presentation/cubit/course_map_cubit.dart';
import 'package:sat_east_client/features/course_map/presentation/cubit/course_map_state.dart';

class _MockRepo extends Mock implements CourseMapRepository {}

const _map = CourseMap(
  courseId: 'c1',
  slug: 'sat-math',
  title: 'SAT Math',
  continueTopic: null,
  units: [],
);

void main() {
  late _MockRepo repo;

  setUp(() => repo = _MockRepo());

  test('L-1: latest overlapping refresh wins over a stale failure', () async {
    final older = Completer<Result<CourseMap>>();
    final newer = Completer<Result<CourseMap>>();
    var calls = 0;
    when(() => repo.getCourseMap()).thenAnswer(
      (_) => calls++ == 0 ? older.future : newer.future,
    );
    final cubit = CourseMapCubit(repo);
    addTearDown(cubit.close);
    final first = cubit.load();
    final second = cubit.load();
    newer.complete(const Success(_map));
    await second;
    older.complete(const Failure(AppError(ErrorCodes.network)));
    await first;
    expect(cubit.state, const CourseMapLoaded(_map));
  });

  test(
    'L-1: refresh keeps loaded content while the request is pending',
    () async {
      final pending = Completer<Result<CourseMap>>();
      var calls = 0;
      when(() => repo.getCourseMap()).thenAnswer(
        (_) =>
            calls++ == 0 ? Future.value(const Success(_map)) : pending.future,
      );
      final cubit = CourseMapCubit(repo);
      addTearDown(cubit.close);
      await cubit.load();
      final refresh = cubit.load();
      final duringRefresh = cubit.state;
      pending.complete(const Success(_map));
      await refresh;
      expect(duringRefresh, const CourseMapLoaded(_map));
      expect(cubit.state, const CourseMapLoaded(_map));
    },
  );

  test(
    'L-1: refresh failure is explicit after preserving loaded content',
    () async {
      var calls = 0;
      when(() => repo.getCourseMap()).thenAnswer(
        (_) async => calls++ == 0
            ? const Success(_map)
            : const Failure(AppError(ErrorCodes.network)),
      );
      final cubit = CourseMapCubit(repo);
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.load();
      expect(cubit.state, const CourseMapFailed(AppError(ErrorCodes.network)));
    },
  );

  blocTest<CourseMapCubit, CourseMapState>(
    'L-1: load success emits Loading then Loaded',
    build: () {
      when(
        () => repo.getCourseMap(),
      ).thenAnswer((_) async => const Success(_map));
      return CourseMapCubit(repo);
    },
    act: (c) => c.load(),
    expect: () => [const CourseMapLoading(), const CourseMapLoaded(_map)],
  );

  for (final code in [
    ErrorCodes.notEnrolled,
    ErrorCodes.accessExpired,
    ErrorCodes.network,
  ]) {
    blocTest<CourseMapCubit, CourseMapState>(
      'L-1: load failing with $code emits Loading then Failed',
      build: () {
        when(
          () => repo.getCourseMap(),
        ).thenAnswer((_) async => Failure(AppError(code)));
        return CourseMapCubit(repo);
      },
      act: (c) => c.load(),
      expect: () => [
        const CourseMapLoading(),
        CourseMapFailed(AppError(code)),
      ],
    );
  }

  blocTest<CourseMapCubit, CourseMapState>(
    'L-1: retry after a failure loads the map',
    build: () {
      var calls = 0;
      when(() => repo.getCourseMap()).thenAnswer(
        (_) async => calls++ == 0
            ? const Failure(AppError(ErrorCodes.network))
            : const Success(_map),
      );
      return CourseMapCubit(repo);
    },
    act: (c) async {
      await c.load();
      await c.retry();
    },
    expect: () => [
      const CourseMapLoading(),
      const CourseMapFailed(AppError(ErrorCodes.network)),
      const CourseMapLoading(),
      const CourseMapLoaded(_map),
    ],
  );

  test(
    'L-1: closing during an in-flight load emits nothing after close',
    () async {
      final completer = Completer<Result<CourseMap>>();
      when(() => repo.getCourseMap()).thenAnswer((_) => completer.future);
      final cubit = CourseMapCubit(repo);
      final emitted = <CourseMapState>[];
      final sub = cubit.stream.listen(emitted.add);

      final pending = cubit.load();
      await cubit.close();
      completer.complete(const Success(_map));
      await pending;
      await sub.cancel();

      expect(emitted.whereType<CourseMapLoaded>(), isEmpty);
    },
  );
}
