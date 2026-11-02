import 'package:equatable/equatable.dart';
import 'package:sat_east_client/features/course_map/domain/entities/course_map.dart';
import 'package:sat_east_client/features/home/domain/entities/current_step.dart';

sealed class HomeSummary extends Equatable {
  const HomeSummary(this.firstName);
  final String firstName;
  @override
  List<Object?> get props => [firstName];
}

final class HomeReady extends HomeSummary {
  const HomeReady({
    required String firstName,
    required this.courseTitle,
    required this.unitTitle,
    required this.topic,
    required this.topicSortLabel,
    required this.step,
    required this.firstRun,
    required this.passed,
    required this.total,
    required this.expiry,
  }) : super(firstName);

  final String courseTitle;
  final String unitTitle;
  final ContinueTopic topic;
  final String topicSortLabel;
  final CurrentStep step;
  final bool firstRun;
  final int passed;
  final int total;
  final ExpiryWarning? expiry;

  @override
  List<Object?> get props => [
    ...super.props,
    courseTitle,
    unitTitle,
    topic,
    topicSortLabel,
    step,
    firstRun,
    passed,
    total,
    expiry,
  ];
}

final class HomeFinished extends HomeSummary {
  const HomeFinished(super.firstName, this.courseTitle, this.total);
  final String courseTitle;
  final int total;
  @override
  List<Object?> get props => [...super.props, courseTitle, total];
}

final class HomeExpired extends HomeSummary {
  const HomeExpired(super.firstName);
}

final class HomeNotEnrolled extends HomeSummary {
  const HomeNotEnrolled(super.firstName);
}

final class ExpiryWarning extends Equatable {
  const ExpiryWarning(this.daysLeft, this.expiresAt);
  final int daysLeft;
  final DateTime expiresAt;
  @override
  List<Object?> get props => [daysLeft, expiresAt];
}
