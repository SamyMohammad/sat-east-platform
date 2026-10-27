import 'package:equatable/equatable.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/topic_option.dart';

class TeacherNote extends Equatable {
  const TeacherNote({
    required this.id,
    required this.title,
    required this.pageCount,
    required this.ready,
    this.subtopicId,
  });
  final String id;
  final String title;
  final int pageCount;
  final bool ready;
  final String? subtopicId;
  String path(String topicId) => '$topicId/$id.pdf';
  @override
  List<Object?> get props => [id, title, pageCount, ready, subtopicId];
}

class CreatedNote {
  const CreatedNote({required this.id, required this.path});
  final String id;
  final String path;
}

class TeacherNotesData extends Equatable {
  TeacherNotesData({
    required this.topicTitle,
    required List<TeacherNote> notes,
    required List<SubtopicOption> subtopics,
    required this.maxMb,
  }) : notes = List.unmodifiable(notes),
       subtopics = List.unmodifiable(subtopics);
  final String topicTitle;
  final List<TeacherNote> notes;
  final List<SubtopicOption> subtopics;
  final int maxMb;
  TeacherNotesData withNotes(List<TeacherNote> value) => TeacherNotesData(
    topicTitle: topicTitle,
    notes: value,
    subtopics: subtopics,
    maxMb: maxMb,
  );
  List<String>? movedIds(String id, int offset) {
    final ids = notes.map((note) => note.id).toList();
    final index = ids.indexOf(id);
    final target = index + offset;
    if (index < 0 || target < 0 || target >= ids.length || offset.abs() != 1) {
      return null;
    }
    ids.insert(target, ids.removeAt(index));
    return ids;
  }

  @override
  List<Object?> get props => [topicTitle, notes, subtopics, maxMb];
}
