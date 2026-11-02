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
import 'package:sat_east_client/features/topic/domain/entities/topic_detail.dart'
    show TopicDetail;
import 'package:sat_east_client/features/topic/domain/repositories/topic_repository.dart';

class GetHomeSummary {
  GetHomeSummary(
    this._maps,
    this._topics,
    this._auth,
    this._settings,
    this._now,
  );

  final CourseMapRepository _maps;
  final TopicRepository _topics;
  final AuthRepository _auth;
  final HomeSettingsRepository _settings;
  final DateTime Function() _now;

  Future<Result<HomeSummary>> call() async {
    final profile = await _auth.getMyProfile();
    if (profile case Failure(:final error)) return Failure(error);
    final name = (profile as Success<MyProfile>).value.fullName.trim();
    final firstName = name.isEmpty ? '' : name.split(RegExp(r'\s+')).first;
    final mapResult = await _maps.getCourseMap();
    if (mapResult case Failure(:final error)) {
      return switch (error.code) {
        ErrorCodes.notEnrolled => Success(HomeNotEnrolled(firstName)),
        ErrorCodes.accessExpired => Success(HomeExpired(firstName)),
        _ => Failure(error),
      };
    }
    final map = (mapResult as Success<CourseMap>).value;
    if (map.access == CourseAccess.preview) {
      return Success(HomeNotEnrolled(firstName));
    }
    final allTopics = map.units.expand((unit) => unit.topics).toList();
    final next = map.continueTopic;
    if (next == null) {
      return Success(HomeFinished(firstName, map.title, allTopics.length));
    }
    final topicResult = await _topics.getTopic(next.topicId);
    if (topicResult case Failure(:final error)) return Failure(error);
    final detail = (topicResult as Success<TopicDetail>).value;
    final step = currentStepOf(detail);
    final passed = allTopics
        .where((topic) => topic.status == TopicStatus.completed)
        .length;
    final mapTopic = allTopics
        .where((topic) => topic.id == next.topicId)
        .firstOrNull;
    return Success(
      HomeReady(
        firstName: firstName,
        courseTitle: map.title,
        unitTitle: next.unitTitle ?? '',
        topic: next,
        topicSortLabel: mapTopic?.sortLabel ?? '',
        step: step,
        firstRun:
            passed == 0 &&
            step is VideoStep &&
            detail.videos.every((video) => video.pct == 0),
        passed: passed,
        total: allTopics.length,
        expiry: await _expiry(map.courseId),
      ),
    );
  }

  Future<ExpiryWarning?> _expiry(String courseId) async {
    final settings = await _settings.expiryWarnDays();
    if (settings case Failure()) return null;
    final enrollments = await _auth.listMyEnrollments();
    if (enrollments case Failure()) return null;
    final enrollment = (enrollments as Success<List<MyEnrollment>>).value
        .where((enrollment) => enrollment.courseId == courseId)
        .firstOrNull;
    if (enrollment == null) return null;
    final daysLeft = enrollment.expiresAt.difference(_now()).inDays;
    final warnDays = (settings as Success<int>).value;
    return 0 < daysLeft && daysLeft < warnDays
        ? ExpiryWarning(daysLeft, enrollment.expiresAt)
        : null;
  }
}
