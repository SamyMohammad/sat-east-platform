import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/questions/data/datasources/question_import_remote_data_source.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/import_report.dart';
import 'package:sat_east_client/features/teacher/questions/domain/repositories/question_import_repository.dart';

class QuestionImportRepositoryImpl implements QuestionImportRepository {
  QuestionImportRepositoryImpl(this._source);
  final QuestionImportRemoteDataSource _source;
  @override
  Future<Result<ImportReport>> dryRun(List<Object?> items) =>
      _source.run(items, commit: false);
  @override
  Future<Result<ImportReport>> commit(List<Object?> items) =>
      _source.run(items, commit: true);
}
