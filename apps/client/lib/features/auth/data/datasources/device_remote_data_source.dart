import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/errors/supabase_error_mapper.dart';
import 'package:sat_east_client/features/auth/data/models/device_model.dart';
import 'package:sat_east_client/features/auth/domain/entities/device_registration.dart';
import 'package:sat_east_client/features/auth/domain/entities/device_status.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef RpcCaller =
    Future<Object?> Function(String fn, Map<String, Object?> params);

const _malformed = AppError(ErrorCodes.internal, 'malformed rpc payload');

/// Device RPCs (`register_device`, `device_status`, `remove_device`).
class DeviceRemoteDataSource {
  DeviceRemoteDataSource(this._rpc);

  final RpcCaller _rpc;

  Future<Result<DeviceRegistration>> register({
    required String fingerprint,
    required String platform,
    required String label,
  }) => _call(
    'register_device',
    {'p_fingerprint': fingerprint, 'p_platform': platform, 'p_label': label},
    _parseRegistration,
  );

  Future<Result<DeviceStatus>> status({required String fingerprint}) => _call(
    'device_status',
    {'p_fingerprint': fingerprint},
    (raw) => switch (raw) {
      'active' => DeviceStatus.active,
      'revoked' => DeviceStatus.revoked,
      'unknown' => DeviceStatus.unknown,
      _ => null,
    },
  );

  Future<Result<int>> remove(String deviceId) => _call(
    'remove_device',
    {'p_device_id': deviceId},
    (raw) => raw is Map && raw['changes_left'] is int
        ? raw['changes_left'] as int
        : null,
  );

  /// Runs the RPC; [parse] returns null (or throws) on an unexpected shape.
  Future<Result<T>> _call<T>(
    String fn,
    Map<String, Object?> params,
    T? Function(Object? raw) parse,
  ) async {
    try {
      final parsed = parse(await _rpc(fn, params));
      return parsed == null ? const Failure(_malformed) : Success(parsed);
    } on PostgrestException catch (e) {
      return Failure(mapPostgrestException(e));
    } on FormatException {
      return const Failure(_malformed);
    } on Object catch (e) {
      return Failure(mapUnknownError(e));
    }
  }

  DeviceRegistration? _parseRegistration(Object? raw) {
    if (raw is! Map) return null;
    switch (raw['status']) {
      case 'ok':
        final id = raw['device_id'];
        return id is String ? DeviceAllowed(id) : null;
      case 'limit_reached':
        final changes = raw['changes_left'];
        final devices = raw['devices'];
        if (changes is! int || devices is! List) return null;
        return DeviceLimitReached(
          devices: [
            for (final d in devices)
              if (d is Map)
                DeviceModel.fromJson(d.cast<String, Object?>())
              else
                throw const FormatException('device not an object'),
          ],
          changesLeft: changes,
        );
      default:
        return null;
    }
  }
}
