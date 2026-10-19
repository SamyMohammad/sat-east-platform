import 'package:equatable/equatable.dart';

class TeacherCourse extends Equatable {
  const TeacherCourse({
    required this.id,
    required this.code,
    required this.title,
    required this.slug,
    required this.isPublished,
  });
  final String id;
  final String code;
  final String title;
  final String slug;
  final bool isPublished;
  @override
  List<Object?> get props => [id, code, title, slug, isPublished];
}

typedef TopicFlags = ({bool isPublished, bool isFreePreview});
