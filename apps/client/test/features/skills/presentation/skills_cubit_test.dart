import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/course_map/domain/entities/course_map.dart';
import 'package:sat_east_client/features/course_map/domain/repositories/course_map_repository.dart';
import 'package:sat_east_client/features/skills/domain/entities/skills_overview.dart';
import 'package:sat_east_client/features/skills/domain/repositories/skills_repository.dart';
import 'package:sat_east_client/features/skills/presentation/cubit/skills_cubit.dart';
import 'package:sat_east_client/features/skills/presentation/cubit/skills_state.dart';

import '../skills_fixtures.dart';

class _MockSkills extends Mock implements SkillsRepository {}

class _MockCourseMap extends Mock implements CourseMapRepository {}

const _map = CourseMap(
  courseId: 'c1',
  slug: 'sat-math',
  title: 'SAT Math',
  continueTopic: null,
  units: [],
);

const _noAnswers = SkillsOverview(
  summary: SkillsSummary(solved: 0, total: 40, gradedAnswers: 0),
  skills: [],
  weak: [],
  trend: [],
  topics: [],
);

void main() {
  late _MockSkills skills;
  late _MockCourseMap courseMap;

  setUp(() {
    skills = _MockSkills();
    courseMap = _MockCourseMap();
    when(courseMap.getCourseMap).thenAnswer((_) async => const Success(_map));
    when(
      () => skills.load('c1'),
    ).thenAnswer((_) async => Success(skillsOverviewFixture));
  });

  SkillsCubit build() => SkillsCubit(skills, courseMap);

  group('ANL-01: SkillsCubit', () {
    blocTest<SkillsCubit, SkillsState>(
      'ANL-01: load_success_emits_loaded',
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [SkillsLoaded(skillsOverviewFixture, 'c1')],
      verify: (_) {
        verify(courseMap.getCourseMap).called(1);
        verify(() => skills.load('c1')).called(1);
      },
    );

    blocTest<SkillsCubit, SkillsState>(
      'ANL-01: load_with_course_id_skips_course_lookup',
      build: build,
      act: (cubit) => cubit.load(courseId: 'c1'),
      expect: () => [SkillsLoaded(skillsOverviewFixture, 'c1')],
      verify: (_) => verifyNever(courseMap.getCourseMap),
    );

    blocTest<SkillsCubit, SkillsState>(
      'ANL-01: load_zero_answers_emits_empty',
      setUp: () => when(
        () => skills.load('c1'),
      ).thenAnswer((_) async => const Success(_noAnswers)),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [const SkillsEmpty()],
    );

    blocTest<SkillsCubit, SkillsState>(
      'ANL-01: load_failure_emits_failed',
      setUp: () => when(() => skills.load('c1')).thenAnswer(
        (_) async => const Failure(AppError(ErrorCodes.accessExpired)),
      ),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [const SkillsFailed(AppError(ErrorCodes.accessExpired))],
    );

    blocTest<SkillsCubit, SkillsState>(
      'ANL-01: load_course_lookup_failure_emits_failed',
      setUp: () => when(courseMap.getCourseMap).thenAnswer(
        (_) async => const Failure(AppError(ErrorCodes.notEnrolled)),
      ),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [const SkillsFailed(AppError(ErrorCodes.notEnrolled))],
      verify: (_) => verifyNever(() => skills.load(any())),
    );

    blocTest<SkillsCubit, SkillsState>(
      'ANL-01: retry_reloads_same_course',
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.retry();
      },
      verify: (_) {
        verify(courseMap.getCourseMap).called(1);
        verify(() => skills.load('c1')).called(2);
      },
    );

    blocTest<SkillsCubit, SkillsState>(
      'ANL-01: retry_after_failed_course_lookup_looks_up_again',
      setUp: () {
        var first = true;
        when(courseMap.getCourseMap).thenAnswer((_) async {
          if (first) {
            first = false;
            return const Failure(AppError(ErrorCodes.network));
          }
          return const Success(_map);
        });
      },
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.retry();
      },
      expect: () => [
        const SkillsFailed(AppError(ErrorCodes.network)),
        const SkillsLoading(),
        SkillsLoaded(skillsOverviewFixture, 'c1'),
      ],
    );

    test('ANL-01: no_emit_after_close', () async {
      final completer = Completer<Result<SkillsOverview>>();
      when(() => skills.load('c1')).thenAnswer((_) => completer.future);
      final cubit = build();
      final states = <SkillsState>[];
      final sub = cubit.stream.listen(states.add);

      final pending = cubit.load();
      await Future<void>.delayed(Duration.zero);
      await cubit.close();
      completer.complete(Success(skillsOverviewFixture));
      await pending;
      await sub.cancel();

      expect(states, isEmpty);
    });
  });
}
