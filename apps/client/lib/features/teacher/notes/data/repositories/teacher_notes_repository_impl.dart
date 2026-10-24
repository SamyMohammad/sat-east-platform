import 'dart:typed_data';

import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/notes/data/datasources/teacher_notes_remote_data_source.dart';
import 'package:sat_east_client/features/teacher/notes/domain/entities/teacher_note.dart';
import 'package:sat_east_client/features/teacher/notes/domain/repositories/teacher_notes_repository.dart';

class TeacherNotesRepositoryImpl implements TeacherNotesRepository {
  TeacherNotesRepositoryImpl(this._source);
  final TeacherNotesRemoteDataSource _source;
  @override
  Future<Result<List<TeacherNote>>> list(String topicId) =>
      _source.list(topicId);
  @override
  Future<Result<int>> maxUploadMb() => _source.maxUploadMb();
  @override
  Future<Result<CreatedNote>> create(String topicId, String title, int pages) =>
      _source.create(topicId, title, pages);
  @override
  Future<Result<void>> upload(String path, Uint8List bytes) =>
      _source.upload(path, bytes);
  @override
  Future<Result<void>> confirm(String id) => _source.confirm(id);
  @override
  Future<Result<void>> remove(String path) => _source.remove(path);
  @override
  Future<Result<void>> delete(String id) => _source.delete(id);
  @override
  Future<Result<void>> update(String id, String title, String? subtopicId) =>
      _source.update(id, title, subtopicId);
  @override
  Future<Result<void>> reorder(String topicId, List<String> ids) =>
      _source.reorder(topicId, ids);
}
