import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/questions/data/datasources/question_editor_remote_data_source.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/question_draft.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/question_save_result.dart';
import 'package:sat_east_client/features/teacher/questions/domain/repositories/question_editor_repository.dart';

class QuestionEditorRepositoryImpl implements QuestionEditorRepository {
  QuestionEditorRepositoryImpl(this._source);
  final QuestionEditorRemoteDataSource _source;
  @override
  Future<Result<QuestionDraft>> get(String id) => _source.get(id);
  @override
  Future<Result<QuestionSaveResult>> save(QuestionDraft draft) =>
      _source.save(draft);
}
