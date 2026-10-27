import 'package:equatable/equatable.dart';
import 'package:sat_east_client/features/teacher/course_builder/domain/entities/builder_topic.dart';

class BuilderUnit extends Equatable {
  BuilderUnit({
    required this.id,
    required this.title,
    required this.sort,
    required this.inUse,
    required List<BuilderTopic> topics,
  }) : topics = List.unmodifiable(topics);
  final String id;
  final String title;
  final int sort;
  final bool inUse;
  final List<BuilderTopic> topics;
  BuilderUnit copyWith({int? sort, List<BuilderTopic>? topics}) => BuilderUnit(
    id: id,
    title: title,
    sort: sort ?? this.sort,
    inUse: inUse,
    topics: topics ?? this.topics,
  );
  @override
  List<Object?> get props => [id, title, sort, inUse, topics];
}
