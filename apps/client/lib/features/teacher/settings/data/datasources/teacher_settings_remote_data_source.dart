import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/errors/supabase_error_mapper.dart';
import 'package:sat_east_client/core/supabase/rpc_caller.dart';
import 'package:sat_east_client/features/teacher/settings/data/models/setting_spec_model.dart';
import 'package:sat_east_client/features/teacher/settings/domain/entities/setting_spec.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeacherSettingsRemoteDataSource {
  TeacherSettingsRemoteDataSource(this._rpc);
  final RpcCaller _rpc;

  Future<Result<List<SettingSpec>>> load() =>
      _call('teacher_get_settings', {}, (raw) {
        if (raw is! List<Object?>) throw const FormatException('list');
        return raw.map((value) {
          if (value is! Map<String, Object?>) {
            throw const FormatException('object');
          }
          return settingSpecFromJson(value);
        }).toList();
      });
  Future<Result<void>> save(Map<String, int> changed) =>
      _call<void>('teacher_update_settings', {'p_values': changed}, (raw) {
        if (raw is! Map<String, Object?> ||
            raw['ok'] != true ||
            raw['updated'] is! List<Object?> ||
            !(raw['updated']! as List<Object?>).every((key) => key is String)) {
          throw const FormatException('save response');
        }
      });

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
      return const Failure(
        AppError(ErrorCodes.internal, 'malformed rpc payload'),
      );
    } on Object catch (e) {
      return Failure(mapUnknownError(e));
    }
  }
}
