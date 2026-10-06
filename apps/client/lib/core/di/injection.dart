import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final GetIt getIt = GetIt.instance;

/// Registers services and repositories as lazy singletons, cubits as
/// factories (ADR-007 §2). Features add their own `register*` calls here.
void configureDependencies() {
  getIt.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);
}
