import 'package:sat_east_client/features/auth/data/datasources/device_id_store.dart';
import 'package:sat_east_client/features/auth/data/datasources/device_info.dart';

/// Records RPC calls; returns [response] or throws [error].
class FakeRpc {
  Object? response;
  Object? error;
  final calls = <(String, Map<String, Object?>)>[];

  Future<Object?> call(String fn, Map<String, Object?> params) async {
    calls.add((fn, params));
    // Tests inject arbitrary exception types.
    // ignore: only_throw_errors
    if (error != null) throw error!;
    return response;
  }
}

class FakeDeviceIdStore implements DeviceIdStore {
  FakeDeviceIdStore(this.id, {this.error});

  final String id;
  final Object? error;

  @override
  Future<String> read() async {
    // Tests inject arbitrary exception types.
    // ignore: only_throw_errors
    if (error != null) throw error!;
    return id;
  }
}

class FakeDeviceInfo implements DeviceInfo {
  @override
  String get platform => 'android';

  @override
  String get label => 'Android app';
}
