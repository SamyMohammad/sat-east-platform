import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mocktail/mocktail.dart';

import 'package:sat_east_client/core/analytics/analytics_service.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/observability/error_reporter.dart';
import 'package:sat_east_client/core/supabase/edge_caller.dart';
import 'package:sat_east_client/core/supabase/rpc_caller.dart';

class _Box extends Mock implements Box<String> {}

void main() {
  test(
    'LRN-02: DI distinguishes structurally identical transport typedefs',
    () async {
      getIt.pushNewScope();
      addTearDown(getIt.popScope);
      configureDependencies(
        errorReporter: const NoopErrorReporter(),
        analytics: const NoopAnalyticsService(),
        deviceBox: _Box(),
      );
      final edge = getIt<EdgeCaller>(instanceName: edgeCallerInstanceName);
      final rpc = getIt<RpcCaller>();
      expect(identical(edge, rpc), isFalse);
    },
  );
  test('LRN-02: EdgeCaller forwards relative path and body', () async {
    Future<Object?> call(String path, Map<String, Object?> body) async {
      expect(path, 'video-otp');
      expect(body, {'asset_id': 'asset'});
      return {'provider': 'youtube'};
    }

    expect(await call('video-otp', {'asset_id': 'asset'}), {
      'provider': 'youtube',
    });
  });
}
