import 'package:equatable/equatable.dart';

final class MyEnrollment extends Equatable {
  const MyEnrollment({
    required this.courseId,
    required this.courseTitle,
    required this.targetTestDate,
    required this.expiresAt,
    required this.isExpired,
  });

  final String courseId;
  final String courseTitle;
  final DateTime? targetTestDate;
  final DateTime expiresAt;
  final bool isExpired;

  @override
  List<Object?> get props => [
    courseId,
    courseTitle,
    targetTestDate,
    expiresAt,
    isExpired,
  ];

  @override
  bool get stringify => false;
}
