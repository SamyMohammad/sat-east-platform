import 'package:equatable/equatable.dart';

final class MyEnrollment extends Equatable {
  const MyEnrollment({
    required this.courseTitle,
    required this.targetTestDate,
    required this.expiresAt,
    required this.isExpired,
  });

  final String courseTitle;
  final DateTime? targetTestDate;
  final DateTime expiresAt;
  final bool isExpired;

  @override
  List<Object?> get props => [
    courseTitle,
    targetTestDate,
    expiresAt,
    isExpired,
  ];

  @override
  bool get stringify => false;
}
