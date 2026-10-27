import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/errors/supabase_error_mapper.dart';
import 'package:sat_east_client/core/supabase/rpc_caller.dart';
import 'package:sat_east_client/features/teacher/questions/data/models/import_report_model.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/import_report.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QuestionImportRemoteDataSource {
  QuestionImportRemoteDataSource(this._rpc);
  final RpcCaller _rpc;
  Future<Result<ImportReport>> run(
    List<Object?> items, {
    required bool commit,
  }) async {
    try {
      return Success(
        importReportFromJson(
          await _rpc('teacher_import_questions', {
            'p_items': items,
            'p_commit': commit,
          }),
        ),
      );
    } on PostgrestException catch (e) {
      return Failure(mapPostgrestException(e));
    } on FormatException {
      return const Failure(AppError(ErrorCodes.internal));
    } on Object catch (e) {
      return Failure(mapUnknownError(e));
    }
  }
}
