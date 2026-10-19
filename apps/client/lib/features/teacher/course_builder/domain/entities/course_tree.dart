import 'package:equatable/equatable.dart';
import 'package:sat_east_client/features/teacher/course_builder/domain/entities/builder_unit.dart';
import 'package:sat_east_client/features/teacher/course_builder/domain/entities/node_kind.dart';

export 'builder_subtopic.dart';
export 'builder_topic.dart';
export 'builder_unit.dart';
export 'teacher_course.dart';

class CourseTree extends Equatable {
  CourseTree({
    required this.courseId,
    required this.title,
    required this.code,
    required List<BuilderUnit> units,
  }) : units = List.unmodifiable(units);
  final String courseId;
  final String title;
  final String code;
  final List<BuilderUnit> units;

  String? parentOf(NodeKind kind, String id) {
    for (final unit in units) {
      if (kind == NodeKind.unit && unit.id == id) {
        return courseId;
      }
      for (final topic in unit.topics) {
        if (kind == NodeKind.topic && topic.id == id) {
          return unit.id;
        }
        if (kind == NodeKind.subtopic &&
            topic.subtopics.any((s) => s.id == id)) {
          return topic.id;
        }
      }
    }
    return null;
  }

  List<String>? childIds(NodeKind kind, String parentId) {
    if (kind == NodeKind.unit) {
      return parentId == courseId ? units.map((u) => u.id).toList() : null;
    }
    for (final unit in units) {
      if (kind == NodeKind.topic && unit.id == parentId) {
        return unit.topics.map((t) => t.id).toList();
      }
      for (final topic in unit.topics) {
        if (kind == NodeKind.subtopic && topic.id == parentId) {
          return topic.subtopics.map((s) => s.id).toList();
        }
      }
    }
    return null;
  }

  CourseTree? reordered(NodeKind kind, String parentId, List<String> ids) {
    final current = childIds(kind, parentId);
    if (current == null ||
        current.length != ids.length ||
        ids.toSet().length != ids.length ||
        !current.toSet().containsAll(ids)) {
      return null;
    }
    final positions = {for (var i = 0; i < ids.length; i++) ids[i]: i + 1};
    final next = units.map((unit) {
      if (kind == NodeKind.unit) {
        return unit.copyWith(sort: positions[unit.id]);
      }
      if (kind == NodeKind.topic && unit.id == parentId) {
        final topics =
            unit.topics.map((t) => t.copyWith(sort: positions[t.id])).toList()
              ..sort((a, b) => a.sort.compareTo(b.sort));
        return unit.copyWith(topics: topics);
      }
      if (kind == NodeKind.subtopic) {
        return unit.copyWith(
          topics: unit.topics.map((topic) {
            if (topic.id != parentId) {
              return topic;
            }
            final subtopics =
                topic.subtopics
                    .map((s) => s.withSort(positions[s.id]!))
                    .toList()
                  ..sort((a, b) => a.sort.compareTo(b.sort));
            return topic.copyWith(subtopics: subtopics);
          }).toList(),
        );
      }
      return unit;
    }).toList();
    if (kind == NodeKind.unit) {
      next.sort((a, b) => a.sort.compareTo(b.sort));
    }
    return CourseTree(
      courseId: courseId,
      title: title,
      code: code,
      units: next,
    );
  }

  @override
  List<Object?> get props => [courseId, title, code, units];
}
