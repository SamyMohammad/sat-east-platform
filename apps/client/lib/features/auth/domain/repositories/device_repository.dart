import 'package:sat_east_client/core/errors/result.dart';

import 'package:sat_east_client/features/auth/domain/entities/device_registration.dart';
import 'package:sat_east_client/features/auth/domain/entities/device_status.dart';
import 'package:sat_east_client/features/auth/domain/entities/my_devices.dart';

abstract interface class DeviceRepository {
  Future<Result<DeviceRegistration>> register();
  Future<Result<DeviceStatus>> status();
  Future<Result<MyDevices>> listMine();

  /// Returns the number of device changes left.
  Future<Result<int>> remove(String deviceId);
}
