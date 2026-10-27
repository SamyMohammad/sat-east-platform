import 'dart:typed_data';

import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/notes/domain/entities/teacher_note.dart';

abstract interface class TeacherNotesRepository {
  Future<Result<List<TeacherNote>>> list(String topicId);
  Future<Result<int>> maxUploadMb();
  Future<Result<CreatedNote>> create(String topicId, String title, int pages);
  Future<Result<void>> upload(String path, Uint8List bytes);
  Future<Result<void>> confirm(String id);
  Future<Result<void>> remove(String path);
  Future<Result<void>> delete(String id);
  Future<Result<void>> update(String id, String title, String? subtopicId);
  Future<Result<void>> reorder(String topicId, List<String> ids);
}
