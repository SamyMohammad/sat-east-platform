import 'package:equatable/equatable.dart';
import 'package:sat_east_client/features/teacher/course_builder/domain/entities/builder_subtopic.dart';

class BuilderTopic extends Equatable {
  BuilderTopic({
    required this.id,
    required this.title,
    required this.slug,
    required this.sort,
    required this.isPublished,
    required this.isFreePreview,
    required this.subtopicCount,
    required this.inUse,
    required List<BuilderSubtopic> subtopics,
  }) : subtopics = List.unmodifiable(subtopics);
  final String id;
  final String title;
  final String slug;
  final int sort;
  final bool isPublished;
  final bool isFreePreview;
  final int subtopicCount;
  final bool inUse;
  final List<BuilderSubtopic> subtopics;
  BuilderTopic copyWith({int? sort, List<BuilderSubtopic>? subtopics}) =>
      BuilderTopic(
        id: id,
        title: title,
        slug: slug,
        sort: sort ?? this.sort,
        isPublished: isPublished,
        isFreePreview: isFreePreview,
        subtopicCount: subtopicCount,
        inUse: inUse,
        subtopics: subtopics ?? this.subtopics,
      );
  @override
  List<Object?> get props => [
    id,
    title,
    slug,
    sort,
    isPublished,
    isFreePreview,
    subtopicCount,
    inUse,
    subtopics,
  ];
}
