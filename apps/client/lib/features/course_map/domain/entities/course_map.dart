import 'package:equatable/equatable.dart';

enum TopicStatus { completed, open, locked }

/// `full` for an enrolled student; `preview` for a signed-in student with no
/// enrolment who may only open the course's free topics (CRS-06).
enum CourseAccess { full, preview }

/// Why a topic is locked.
sealed class LockReason extends Equatable {
  const LockReason();
}

/// Locked until the quiz of the topic titled [afterTitle] is passed.
final class PreviousQuiz extends LockReason {
  const PreviousQuiz(this.afterTitle);

  final String afterTitle;

  @override
  List<Object?> get props => [afterTitle];
}

/// Locked because the student has no enrolment and the topic is not free.
final class NeedsAccess extends LockReason {
  const NeedsAccess();

  @override
  List<Object?> get props => const [];
}

/// The student's map of one course: units of topics with progress state.
class CourseMap extends Equatable {
  const CourseMap({
    required this.courseId,
    required this.slug,
    required this.title,
    required this.continueTopic,
    required this.units,
    this.access = CourseAccess.full,
  });

  final String courseId;
  final String slug;
  final String title;
  final ContinueTopic? continueTopic;
  final List<MapUnit> units;
  final CourseAccess access;

  @override
  List<Object?> get props => [
    courseId,
    slug,
    title,
    continueTopic,
    units,
    access,
  ];
}

/// The topic the "Continue" action should open.
class ContinueTopic extends Equatable {
  const ContinueTopic({
    required this.topicId,
    required this.slug,
    required this.title,
    required this.unitTitle,
  });

  final String topicId;
  final String slug;
  final String title;
  final String? unitTitle;

  @override
  List<Object?> get props => [topicId, slug, title, unitTitle];
}

/// A unit; [title] is null for topics that sit outside any unit.
class MapUnit extends Equatable {
  const MapUnit({required this.title, required this.topics});

  final String? title;
  final List<MapTopic> topics;

  @override
  List<Object?> get props => [title, topics];
}

class MapTopic extends Equatable {
  const MapTopic({
    required this.id,
    required this.slug,
    required this.title,
    required this.sortLabel,
    required this.isFreePreview,
    required this.status,
    required this.lockReason,
  });

  final String id;
  final String slug;
  final String title;
  final String sortLabel;
  final bool isFreePreview;
  final TopicStatus status;
  final LockReason? lockReason;

  @override
  List<Object?> get props => [
    id,
    slug,
    title,
    sortLabel,
    isFreePreview,
    status,
    lockReason,
  ];
}
