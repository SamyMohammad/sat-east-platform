import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/notes/domain/entities/teacher_note.dart';
import 'package:sat_east_client/features/teacher/notes/domain/repositories/teacher_notes_repository.dart';
import 'package:sat_east_client/features/teacher/notes/domain/services/pdf_page_counter.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/topic_option.dart';
import 'package:sat_east_client/features/teacher/questions/domain/repositories/question_bank_repository.dart';
import 'package:sat_east_client/features/teacher/questions/domain/services/file_picker_service.dart';

/// Coordinates the multi-step notes workflow, including compensating cleanup.
class TeacherNotesActions {
  TeacherNotesActions(this._repo, this._bank, this._picker, this._counter);
  final TeacherNotesRepository _repo;
  final QuestionBankRepository _bank;
  final FilePickerService _picker;
  final PdfPageCounter _counter;

  Future<Result<TeacherNotesData>> load(String topicId) async {
    final limit = await _repo.maxUploadMb();
    if (limit case Failure(:final error)) return Failure(error);
    final tree = await _bank.topics();
    if (tree case Failure(:final error)) return Failure(error);
    TopicOption? topic;
    for (final course in (tree as Success<List<BankCourse>>).value) {
      for (final entry in course.topics) {
        if (entry.id == topicId) topic = entry;
      }
    }
    if (topic == null) return const Failure(AppError(ErrorCodes.invalidInput));
    final notes = await _repo.list(topicId);
    return switch (notes) {
      Failure(:final error) => Failure(error),
      Success(:final value) => Success(
        TeacherNotesData(
          topicTitle: topic.title,
          notes: value,
          subtopics: topic.subtopics,
          maxMb: (limit as Success<int>).value,
        ),
      ),
    };
  }

  Future<Result<PickedPdf>> pickPdf() => _picker.pickPdf();
  Future<Result<List<TeacherNote>>> list(String topicId) => _repo.list(topicId);

  Future<Result<void>> upload(String topicId, PickedPdf file, int maxMb) async {
    if (!file.name.toLowerCase().endsWith('.pdf')) {
      return const Failure(AppError(ErrorCodes.notesPdfRequired));
    }
    if (file.size > maxMb * 1024 * 1024) {
      return const Failure(AppError(ErrorCodes.notesTooLarge));
    }
    if (file.size == 0) {
      return const Failure(AppError(ErrorCodes.notesInvalidPdf));
    }
    final pages = await _counter.count(file.bytes);
    if (pages case Failure(:final error)) return Failure(error);
    final title = file.name.substring(0, file.name.length - 4).trim();
    if (title.isEmpty || title.length > 120) {
      return const Failure(AppError(ErrorCodes.invalidInput));
    }
    final created = await _repo.create(
      topicId,
      title,
      (pages as Success<int>).value,
    );
    if (created case Failure(:final error)) return Failure(error);
    final asset = (created as Success<CreatedNote>).value;
    final uploaded = await _repo.upload(asset.path, file.bytes);
    final result = uploaded is Failure<void>
        ? uploaded
        : await _repo.confirm(asset.id);
    if (result is Failure<void>) {
      final removed = await _repo.remove(asset.path);
      final deleted = await _repo.delete(asset.id);
      if (removed is Failure<void> || deleted is Failure<void>) {
        return const Failure(AppError(ErrorCodes.notesCleanupFailed));
      }
    }
    return result;
  }

  Future<Result<void>> delete(String topicId, TeacherNote note) async {
    final removed = await _repo.remove(note.path(topicId));
    if (removed is Failure<void>) return removed;
    return _repo.delete(note.id);
  }

  Future<Result<void>> rename(TeacherNote note, String title) =>
      _repo.update(note.id, title, note.subtopicId);
  Future<Result<void>> setSubtopic(
    TeacherNote note,
    String? id,
    List<SubtopicOption> subtopics,
  ) {
    if (id != null && !subtopics.any((subtopic) => subtopic.id == id)) {
      return Future.value(const Failure(AppError(ErrorCodes.invalidInput)));
    }
    return _repo.update(note.id, note.title, id);
  }

  Future<Result<void>> reorder(String topicId, List<String> ids) =>
      _repo.reorder(topicId, ids);
}
