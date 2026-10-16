import 'package:equatable/equatable.dart';
import 'package:sat_east_client/features/auth/domain/entities/device.dart';

/// Result of `register_device`.
sealed class DeviceRegistration extends Equatable {
  const DeviceRegistration();
}

final class DeviceAllowed extends DeviceRegistration {
  const DeviceAllowed(this.deviceId);

  final String deviceId;

  @override
  List<Object?> get props => [deviceId];
}

final class DeviceLimitReached extends DeviceRegistration {
  const DeviceLimitReached({required this.devices, required this.changesLeft});

  final List<Device> devices;
  final int changesLeft;

  @override
  List<Object?> get props => [devices, changesLeft];
}
