import 'package:get_it/get_it.dart';
import 'package:sat_east_client/core/analytics/analytics_service.dart';
import 'package:sat_east_client/core/observability/error_reporter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final GetIt getIt = GetIt.instance;

/// Registers services and repositories as lazy singletons, cubits as
/// factories (ADR-007 §2). Features add their own `register*` calls here.
///
/// [errorReporter] and [analytics] are built in `main.dart` because they must
/// exist before the app starts (ADR-008).
void configureDependencies({
  required ErrorReporter errorReporter,
  required AnalyticsService analytics,
}) {
  getIt
    ..registerLazySingleton<SupabaseClient>(() => Supabase.instance.client)
    ..registerSingleton<ErrorReporter>(errorReporter)
    ..registerSingleton<AnalyticsService>(analytics);
}
