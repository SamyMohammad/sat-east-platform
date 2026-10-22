import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/import_report.dart';

abstract interface class QuestionImportRepository {
  Future<Result<ImportReport>> dryRun(List<Object?> items);
  Future<Result<ImportReport>> commit(List<Object?> items);
}
