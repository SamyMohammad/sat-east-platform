import 'package:equatable/equatable.dart';
import 'package:sat_east_client/features/catalogue/domain/entities/syllabus_topic.dart';

class CourseUnit extends Equatable {
  const CourseUnit({
    required this.title,
    required this.topics,
  });

  final String title;
  final List<SyllabusTopic> topics;

  @override
  List<Object?> get props => [title, topics];
}
