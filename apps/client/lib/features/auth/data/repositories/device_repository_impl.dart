import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/errors/supabase_error_mapper.dart';
import 'package:sat_east_client/features/auth/data/datasources/device_id_store.dart';
import 'package:sat_east_client/features/auth/data/datasources/device_info.dart';
import 'package:sat_east_client/features/auth/data/datasources/device_remote_data_source.dart';
import 'package:sat_east_client/features/auth/domain/entities/device_registration.dart';
import 'package:sat_east_client/features/auth/domain/entities/device_status.dart';
import 'package:sat_east_client/features/auth/domain/repositories/device_repository.dart';

class DeviceRepositoryImpl implements DeviceRepository {
  DeviceRepositoryImpl({
    required this._idStore,
    required this._info,
    required this._remote,
  });

  final DeviceIdStore _idStore;
  final DeviceInfo _info;
  final DeviceRemoteDataSource _remote;

  @override
  Future<Result<DeviceRegistration>> register() async {
    try {
      return await _remote.register(
        fingerprint: await _idStore.read(),
        platform: _info.platform,
        label: _info.label,
      );
    } on Object catch (e) {
      return Failure(mapUnknownError(e));
    }
  }

  @override
  Future<Result<DeviceStatus>> status() async {
    try {
      return await _remote.status(fingerprint: await _idStore.read());
    } on Object catch (e) {
      return Failure(mapUnknownError(e));
    }
  }

  @override
  Future<Result<int>> remove(String deviceId) => _remote.remove(deviceId);
}
