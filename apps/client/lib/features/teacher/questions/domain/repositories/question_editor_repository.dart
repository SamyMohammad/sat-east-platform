import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/question_draft.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/question_save_result.dart';

abstract interface class QuestionEditorRepository {
  Future<Result<QuestionDraft>> get(String id);
  Future<Result<QuestionSaveResult>> save(QuestionDraft draft);
}
