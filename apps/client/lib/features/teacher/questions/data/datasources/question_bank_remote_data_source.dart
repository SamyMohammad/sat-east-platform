import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/errors/supabase_error_mapper.dart';
import 'package:sat_east_client/core/supabase/rpc_caller.dart';
import 'package:sat_east_client/features/teacher/questions/data/models/bank_models.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/bank_filter.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/bank_page.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/topic_option.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QuestionBankRemoteDataSource {
  QuestionBankRemoteDataSource(this._rpc);
  final RpcCaller _rpc;
  Future<Result<BankPage>> list(BankFilter filter, int page) => _call(
    'teacher_list_questions',
    {'p_filter': bankFilterToJson(filter), 'p_page': page},
    bankPageFromJson,
  );
  Future<Result<List<BankCourse>>> topics() =>
      _call('teacher_list_topics_tree', {}, bankTopicsFromJson);
  Future<Result<T>> _call<T>(
    String fn,
    Map<String, Object?> params,
    T Function(Object?) parse,
  ) async {
    try {
      return Success(parse(await _rpc(fn, params)));
    } on PostgrestException catch (e) {
      return Failure(mapPostgrestException(e));
    } on FormatException {
      return const Failure(AppError(ErrorCodes.internal));
    } on Object catch (e) {
      return Failure(mapUnknownError(e));
    }
  }
}
