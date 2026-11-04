import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/auth/domain/entities/my_enrollment.dart';
import 'package:sat_east_client/features/auth/domain/entities/my_profile.dart';
import 'package:sat_east_client/features/auth/domain/repositories/auth_repository.dart';
import 'package:sat_east_client/features/course_map/domain/entities/course_map.dart';
import 'package:sat_east_client/features/course_map/domain/repositories/course_map_repository.dart';
import 'package:sat_east_client/features/home/domain/entities/current_step.dart';
import 'package:sat_east_client/features/home/domain/entities/home_summary.dart';
import 'package:sat_east_client/features/home/domain/repositories/home_settings_repository.dart';
import 'package:sat_east_client/features/home/domain/usecases/get_home_summary.dart';
import 'package:sat_east_client/features/topic/domain/repositories/topic_repository.dart';

import 'current_step_test.dart' as fixtures;

class _MapRepository extends Mock implements CourseMapRepository {}

class _TopicRepository extends Mock implements TopicRepository {}

class _AuthRepository extends Mock implements AuthRepository {}

class _SettingsRepository extends Mock implements HomeSettingsRepository {}

const _continue = ContinueTopic(
  topicId: 'topic-id',
  slug: 'linear',
  title: 'Linear equations',
  unitTitle: 'Algebra',
);
const _open = MapTopic(
  id: 'topic-id',
  slug: 'linear',
  title: 'Linear equations',
  sortLabel: '1.2',
  isFreePreview: false,
  status: TopicStatus.open,
  lockReason: null,
);
const _completed = MapTopic(
  id: 'done',
  slug: 'done',
  title: 'Basics',
  sortLabel: '1.1',
  isFreePreview: false,
  status: TopicStatus.completed,
  lockReason: null,
);
CourseMap _map({
  ContinueTopic? next = _continue,
  CourseAccess access = CourseAccess.full,
  List<MapTopic> topics = const [_completed, _open],
}) => CourseMap(
  courseId: 'sat-id',
  slug: 'sat',
  title: 'SAT Math',
  continueTopic: next,
  units: [MapUnit(title: 'Algebra', topics: topics)],
  access: access,
);
final _now = DateTime.utc(2026, 11, 2);
MyEnrollment _enrollment(String courseId, int days) => MyEnrollment(
  courseId: courseId,
  courseTitle: 'SAT Math',
  targetTestDate: null,
  expiresAt: _now.add(Duration(days: days)),
  isExpired: days <= 0,
);

void main() {
  late _MapRepository maps;
  late _TopicRepository topics;
  late _AuthRepository auth;
  late _SettingsRepository settings;
  late GetHomeSummary getSummary;
  setUp(() {
    maps = _MapRepository();
    topics = _TopicRepository();
    auth = _AuthRepository();
    settings = _SettingsRepository();
    getSummary = GetHomeSummary(maps, topics, auth, settings, () => _now);
    when(() => maps.getCourseMap()).thenAnswer((_) async => Success(_map()));
    when(
      () => topics.getTopic('topic-id'),
    ).thenAnswer((_) async => Success(fixtures.topic(count: 3)));
    when(() => auth.getMyProfile()).thenAnswer(
      (_) async => const Success(
        MyProfile(
          fullName: 'Abdelrahman Elmenshawy',
          email: 'student@example.com',
        ),
      ),
    );
    when(
      () => auth.listMyEnrollments(),
    ).thenAnswer((_) async => Success([_enrollment('sat-id', 9)]));
    when(
      () => settings.expiryWarnDays(),
    ).thenAnswer((_) async => const Success(14));
  });
  Future<HomeSummary> load() async =>
      (await getSummary() as Success<HomeSummary>).value;
  Future<HomeReady> ready() async => await load() as HomeReady;

  test('LRN-07: ready with step and counts', () async {
    final summary = await ready();
    expect(summary.courseTitle, 'SAT Math');
    expect(summary.unitTitle, 'Algebra');
    expect(summary.topic, _continue);
    expect(summary.topicSortLabel, '1.2');
    expect(summary.step, const PracticeStep(3, 5));
    expect(summary.passed, 1);
    expect(summary.total, 2);
    expect(summary.firstRun, false);
  });
  test('LRN-07: first run', () async {
    when(
      () => maps.getCourseMap(),
    ).thenAnswer((_) async => Success(_map(topics: [_open])));
    when(() => topics.getTopic('topic-id')).thenAnswer(
      (_) async => Success(
        fixtures.topic(
          videos: [fixtures.video('first', 0), fixtures.video('second', 0)],
          videoDone: false,
        ),
      ),
    );
    expect((await ready()).firstRun, true);
  });
  test('LRN-07: watched video is not first run', () async {
    when(
      () => maps.getCourseMap(),
    ).thenAnswer((_) async => Success(_map(topics: [_open])));
    when(() => topics.getTopic('topic-id')).thenAnswer(
      (_) async => Success(
        fixtures.topic(videos: [fixtures.video('first', 1)], videoDone: false),
      ),
    );
    expect((await ready()).firstRun, false);
  });
  test('LRN-07: finished when no continue topic', () async {
    when(
      () => maps.getCourseMap(),
    ).thenAnswer((_) async => Success(_map(next: null, topics: [_completed])));
    final summary = await load() as HomeFinished;
    expect(summary.firstName, 'Abdelrahman');
    expect(summary.courseTitle, 'SAT Math');
    expect(summary.total, 1);
    verifyNever(() => topics.getTopic(any()));
  });
  test('LRN-07: not_enrolled -> HomeNotEnrolled', () async {
    when(
      () => maps.getCourseMap(),
    ).thenAnswer((_) async => const Failure(AppError(ErrorCodes.notEnrolled)));
    expect(await load(), const HomeNotEnrolled('Abdelrahman'));
  });
  test('LRN-07: preview access -> HomeNotEnrolled', () async {
    when(
      () => maps.getCourseMap(),
    ).thenAnswer((_) async => Success(_map(access: CourseAccess.preview)));
    expect(await load(), const HomeNotEnrolled('Abdelrahman'));
    verifyNever(() => topics.getTopic(any()));
  });
  test('LRN-07: access_expired -> HomeExpired', () async {
    when(() => maps.getCourseMap()).thenAnswer(
      (_) async => const Failure(AppError(ErrorCodes.accessExpired)),
    );
    expect(await load(), const HomeExpired('Abdelrahman'));
  });
  test('LRN-07: topic failure -> Failure', () async {
    const error = AppError(ErrorCodes.network);
    when(
      () => topics.getTopic('topic-id'),
    ).thenAnswer((_) async => const Failure(error));
    expect((await getSummary() as Failure).error, same(error));
  });
  test('LRN-07: map failure -> Failure', () async {
    const error = AppError(ErrorCodes.network);
    when(
      () => maps.getCourseMap(),
    ).thenAnswer((_) async => const Failure(error));
    expect((await getSummary() as Failure).error, same(error));
  });
  test('LRN-07: profile failure -> Failure', () async {
    const error = AppError(ErrorCodes.network);
    when(
      () => auth.getMyProfile(),
    ).thenAnswer((_) async => const Failure(error));
    expect((await getSummary() as Failure).error, same(error));
  });
  test('LRN-07: expiry banner when 9 days left and warn 14', () async {
    expect(
      (await ready()).expiry,
      ExpiryWarning(9, _now.add(const Duration(days: 9))),
    );
  });
  test('LRN-07: no banner at exactly 14 days', () async {
    when(
      () => auth.listMyEnrollments(),
    ).thenAnswer((_) async => Success([_enrollment('sat-id', 14)]));
    expect((await ready()).expiry, isNull);
  });
  test('LRN-07: banner uses enrolment matching course id', () async {
    when(() => auth.listMyEnrollments()).thenAnswer(
      (_) async =>
          Success([_enrollment('est-id', 2), _enrollment('sat-id', 9)]),
    );
    expect((await ready()).expiry!.daysLeft, 9);
  });
  test('LRN-07: no matching enrolment means no banner', () async {
    when(
      () => auth.listMyEnrollments(),
    ).thenAnswer((_) async => Success([_enrollment('est-id', 2)]));
    expect((await ready()).expiry, isNull);
  });
  test('LRN-07: settings failure -> no banner, still ready', () async {
    when(
      () => settings.expiryWarnDays(),
    ).thenAnswer((_) async => const Failure(AppError(ErrorCodes.network)));
    expect((await ready()).expiry, isNull);
  });
  test('LRN-07: enrollment failure -> no banner, still ready', () async {
    when(
      () => auth.listMyEnrollments(),
    ).thenAnswer((_) async => const Failure(AppError(ErrorCodes.network)));
    expect((await ready()).expiry, isNull);
  });
  for (final days in [-1, 0, 15]) {
    test('LRN-07: no banner with $days days left', () async {
      when(
        () => auth.listMyEnrollments(),
      ).thenAnswer((_) async => Success([_enrollment('sat-id', days)]));
      expect((await ready()).expiry, isNull);
    });
  }
  test(
    "LRN-07: first name from 'Abdelrahman Elmenshawy' is 'Abdelrahman'",
    () async {
      expect((await ready()).firstName, 'Abdelrahman');
    },
  );
  for (final (name, expected) in [
    ('  Abdelrahman \t Elmenshawy  ', 'Abdelrahman'),
    ('  ', ''),
  ]) {
    test('LRN-07: first name handles whitespace in "$name"', () async {
      when(
        () => auth.getMyProfile(),
      ).thenAnswer((_) async => Success(MyProfile(fullName: name, email: '')));
      expect((await ready()).firstName, expected);
    });
  }
}
