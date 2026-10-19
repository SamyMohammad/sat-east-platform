import 'package:equatable/equatable.dart';

class ActivationResult extends Equatable {
  const ActivationResult({
    required this.courseId,
    required this.courseSlug,
    required this.courseTitle,
    required this.targetTestDate,
    required this.expiresAt,
  });

  final String courseId;
  final String courseSlug;
  final String courseTitle;
  final DateTime targetTestDate;
  final DateTime expiresAt;

  @override
  List<Object?> get props => [
    courseId,
    courseSlug,
    courseTitle,
    targetTestDate,
    expiresAt,
  ];
}
