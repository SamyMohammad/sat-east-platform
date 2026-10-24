import 'package:sat_east_client/features/teacher/questions/domain/entities/import_report.dart';

sealed class QuestionSaveResult {
  const QuestionSaveResult();
}

final class QuestionSaved extends QuestionSaveResult {
  const QuestionSaved({required this.id, required this.version});
  final String id;
  final int version;
}

final class QuestionRejected extends QuestionSaveResult {
  QuestionRejected(List<ImportProblem> errors)
    : errors = List.unmodifiable(errors);
  final List<ImportProblem> errors;
}
