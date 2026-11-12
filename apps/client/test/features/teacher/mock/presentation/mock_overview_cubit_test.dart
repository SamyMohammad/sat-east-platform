import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/mock/domain/entities/mock_entities.dart';
import 'package:sat_east_client/features/teacher/mock/domain/usecases/find_sat_course.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/cubit/mock_overview_cubit.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/cubit/mock_overview_state.dart';

import '../../course_builder/builder_fixtures.dart';
import '../mock_fakes.dart';
import '../mock_fixtures.dart';

({
  MockOverviewCubit cubit,
  FakeTeacherMockRepository mock,
  FakeBuilderRepository courses,
})
_make() {
  final mock = FakeTeacherMockRepository();
  final courses = FakeBuilderRepository();
  return (
    cubit: MockOverviewCubit(mock, FindSatCourse(courses)),
    mock: mock,
    courses: courses,
  );
}

void main() {
  test('MCK-03: load picks the SAT course among [EST, SAT]', () async {
    final t = _make();
    t.courses.courses = Success(builderCourses.reversed.toList());
    await t.cubit.load();
    final state = t.cubit.state as MockOverviewLoaded;
    expect(state.courseId, 'c1');
    expect(state.overview, readyOverview);
    expect(t.mock.calls.single.$1, 'overview');
    expect(t.mock.calls.single.$2, ['c1']);
  });

  test('MCK-03: no SAT course gives NoCourse and no mock RPC', () async {
    final t = _make();
    t.courses.courses = Success(
      builderCourses.where((c) => c.code != 'SAT').toList(),
    );
    await t.cubit.load();
    expect(t.cubit.state, isA<MockOverviewNoCourse>());
    expect(t.mock.calls, isEmpty);
  });

  test('MCK-03: course list failure gives Failed', () async {
    final t = _make();
    t.courses.courses = const Failure(AppError('network'));
    await t.cubit.load();
    expect((t.cubit.state as MockOverviewFailed).error.code, 'network');
    expect(t.mock.calls, isEmpty);
  });

  test('MCK-03: overview failure gives Failed and retry recovers', () async {
    final t = _make();
    t.mock.overviewResult = const Failure(AppError('internal'));
    await t.cubit.load();
    expect(t.cubit.state, isA<MockOverviewFailed>());
    t.mock.overviewResult = Success(readyOverview);
    await t.cubit.retry();
    expect(t.cubit.state, isA<MockOverviewLoaded>());
  });

  test('MCK-03: assemble success returns the form and reloads', () async {
    final t = _make();
    await t.cubit.load();
    final result = await t.cubit.assemble(1);
    expect(result, const Assembled(setNo: 1, formNo: 3));
    expect(t.mock.calls.map((c) => c.$1), ['overview', 'assemble', 'overview']);
    expect(t.mock.calls[1].$2, ['c1', 1]);
    final state = t.cubit.state as MockOverviewLoaded;
    expect(state.busy, isFalse);
    expect(state.lastShortage, isNull);
  });

  test('MCK-03: assemble shortage stores it, returns null, reloads', () async {
    final t = _make();
    await t.cubit.load();
    t.mock.assembleResult = const Success(
      Shortage(missing: [parsedShortage], noDomain: 2),
    );
    t.mock.overviewResult = Success(shortOverview);
    final result = await t.cubit.assemble(1);
    expect(result, isNull);
    final state = t.cubit.state as MockOverviewLoaded;
    expect(state.lastShortage, isNotNull);
    expect(state.lastShortage!.noDomain, 2);
    expect(state.overview, shortOverview);
    expect(state.busy, isFalse);
  });

  test('MCK-03: assemble failure sets lastError and stays loaded', () async {
    final t = _make();
    await t.cubit.load();
    t.mock.assembleResult = const Failure(AppError('forbidden'));
    final result = await t.cubit.assemble(1);
    expect(result, isNull);
    final state = t.cubit.state as MockOverviewLoaded;
    expect(state.lastError?.code, 'forbidden');
    expect(state.overview, readyOverview);
    expect(state.busy, isFalse);
  });

  test('MCK-03: assemble before a loaded state does nothing', () async {
    final t = _make();
    expect(await t.cubit.assemble(1), isNull);
    expect(t.mock.calls, isEmpty);
  });
  test('MCK-03: a second assemble while busy makes no second RPC', () async {
    final t = _make();
    await t.cubit.load();
    t.mock.gate = Completer<void>();
    final first = t.cubit.assemble(1);
    expect(await t.cubit.assemble(1), isNull);
    expect(t.mock.count('assemble'), 1);
    expect((t.cubit.state as MockOverviewLoaded).busy, isTrue);
    t.mock.gate!.complete();
    expect(await first, const Assembled(setNo: 1, formNo: 3));
  });

  test('MCK-03: refresh failing after assemble keeps the form', () async {
    final t = _make();
    await t.cubit.load();
    t.mock.overviewResult = const Failure(AppError('network'));
    final result = await t.cubit.assemble(1);
    expect(result, const Assembled(setNo: 1, formNo: 3));
    final state = t.cubit.state as MockOverviewLoaded;
    expect(state.overview, readyOverview);
    expect(state.lastError?.code, 'network');
    expect(state.busy, isFalse);
  });
}
