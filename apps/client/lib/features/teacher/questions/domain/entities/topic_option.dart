import 'package:equatable/equatable.dart';

class BankCourse extends Equatable {
  BankCourse({required this.courseCode, required List<TopicOption> topics})
    : topics = List.unmodifiable(topics);
  final String courseCode;
  final List<TopicOption> topics;
  @override
  List<Object?> get props => [courseCode, topics];
}

class TopicOption extends Equatable {
  TopicOption({
    required this.id,
    required this.slug,
    required this.title,
    required List<SubtopicOption> subtopics,
  }) : subtopics = List.unmodifiable(subtopics);
  final String id;
  final String slug;
  final String title;
  final List<SubtopicOption> subtopics;
  @override
  List<Object?> get props => [id, slug, title, subtopics];
}

class SubtopicOption extends Equatable {
  const SubtopicOption({
    required this.id,
    required this.slug,
    required this.title,
  });
  final String id;
  final String slug;
  final String title;
  @override
  List<Object?> get props => [id, slug, title];
}
