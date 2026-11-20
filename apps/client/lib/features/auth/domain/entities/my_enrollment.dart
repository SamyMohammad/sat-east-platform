import 'package:equatable/equatable.dart';

final class MyEnrollment extends Equatable {
  const MyEnrollment({
    required this.courseId,
    required this.courseTitle,
    required this.targetTestDate,
    required this.expiresAt,
    required this.isExpired,
    this.courseCode,
  });

  final String courseId;
  final String courseTitle;
  final DateTime? targetTestDate;
  final DateTime expiresAt;
  final bool isExpired;

  /// `courses.code` (`SAT` / `EST`).
  final String? courseCode;

  @override
  List<Object?> get props => [
    courseId,
    courseTitle,
    targetTestDate,
    expiresAt,
    isExpired,
    courseCode,
  ];

  @override
  bool get stringify => false;
}
