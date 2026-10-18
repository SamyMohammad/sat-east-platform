import 'package:equatable/equatable.dart';

import 'package:sat_east_client/features/auth/domain/entities/device.dart';

final class MyDevices extends Equatable {
  MyDevices({required List<Device> devices, required this.changesLeft})
    : devices = List.unmodifiable(devices);

  final List<Device> devices;
  final int changesLeft;

  @override
  List<Object?> get props => [devices, changesLeft];
}
