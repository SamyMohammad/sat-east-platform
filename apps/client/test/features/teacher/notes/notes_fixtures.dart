import 'dart:typed_data';

import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/notes/domain/entities/teacher_note.dart';
import 'package:sat_east_client/features/teacher/notes/domain/repositories/teacher_notes_repository.dart';
import 'package:sat_east_client/features/teacher/notes/domain/services/pdf_page_counter.dart';
import 'package:sat_east_client/features/teacher/notes/domain/usecases/teacher_notes_actions.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/picked_file.dart';
import 'package:sat_east_client/features/teacher/questions/domain/services/file_picker_service.dart';

import '../questions/bank_fixtures.dart';
import '../questions/import_fixtures.dart';

const List<TeacherNote> notes = [
  TeacherNote(id: 'a1', title: 'Algebra notes', pageCount: 3, ready: true),
  TeacherNote(
    id: 'a2',
    title: 'More notes',
    pageCount: 2,
    ready: false,
    subtopicId: 's1',
  ),
];
PickedPdf pdf({String name = 'notes.pdf', int size = 3}) =>
    PickedPdf(name: name, bytes: Uint8List(size));

class FakePdfCounter implements PdfPageCounter {
  Result<int> result = const Success(3);
  int calls = 0;
  @override
  Future<Result<int>> count(Uint8List bytes) async {
    calls++;
    return result;
  }
}

class FakeTeacherNotesRepository implements TeacherNotesRepository {
  final List<String> calls = [];
  final Map<String, AppError> failures = {};
  Future<Result<void>>? pending;
  Result<List<TeacherNote>> listResult = const Success(notes);
  Result<int> limitResult = const Success(1);
  @override
  Future<Result<List<TeacherNote>>> list(String topicId) async {
    calls.add('list:$topicId');
    return listResult;
  }

  @override
  Future<Result<int>> maxUploadMb() async => limitResult;
  @override
  Future<Result<CreatedNote>> create(
    String topicId,
    String title,
    int pages,
  ) async {
    calls.add('create:$topicId:$title:$pages');
    final error = failures['create'];
    return error == null
        ? const Success(CreatedNote(id: 'new', path: 't1/new.pdf'))
        : Failure(error);
  }

  Future<Result<void>> _run(String op, String detail) async {
    calls.add('$op:$detail');
    final error = failures[op];
    return error == null ? pending ?? const Success(null) : Failure(error);
  }

  @override
  Future<Result<void>> upload(String path, Uint8List bytes) =>
      _run('upload', path);
  @override
  Future<Result<void>> confirm(String id) => _run('confirm', id);
  @override
  Future<Result<void>> remove(String path) => _run('remove', path);
  @override
  Future<Result<void>> delete(String id) => _run('delete', id);
  @override
  Future<Result<void>> update(String id, String title, String? subtopicId) =>
      _run('update', '$id:$title:$subtopicId');
  @override
  Future<Result<void>> reorder(String topicId, List<String> ids) =>
      _run('reorder', '$topicId:${ids.join(',')}');
}

TeacherNotesActions actions(
  FakeTeacherNotesRepository repo, {
  FakePdfCounter? counter,
  FilePickerService? picker,
  FakeBankRepository? bank,
}) => TeacherNotesActions(
  repo,
  bank ?? FakeBankRepository(),
  picker ?? FakeFilePicker(),
  counter ?? FakePdfCounter(),
);

class FakePdfPicker implements FilePickerService {
  Result<PickedPdf> result = Success(pdf());
  Future<Result<PickedPdf>>? pending;
  @override
  Future<Result<PickedPdf>> pickPdf() async => pending ?? result;
  @override
  Future<Result<PickedFile>> pickJson() async =>
      const Failure(AppError('cancelled'));
}
