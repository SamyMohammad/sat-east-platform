import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/features/auth/data/datasources/device_id_store.dart';
import 'package:sat_east_client/features/auth/data/datasources/device_info.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockSupabaseClient extends Mock implements SupabaseClient {}

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
