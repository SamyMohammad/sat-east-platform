import 'package:get_it/get_it.dart';
import 'package:hive_ce/hive.dart';
import 'package:sat_east_client/core/analytics/analytics_service.dart';
import 'package:sat_east_client/core/observability/error_reporter.dart';
import 'package:sat_east_client/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:sat_east_client/features/auth/data/datasources/device_id_store.dart';
import 'package:sat_east_client/features/auth/data/datasources/device_info.dart';
import 'package:sat_east_client/features/auth/data/datasources/device_remote_data_source.dart';
import 'package:sat_east_client/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:sat_east_client/features/auth/data/repositories/device_repository_impl.dart';
import 'package:sat_east_client/features/auth/domain/repositories/auth_repository.dart';
import 'package:sat_east_client/features/auth/domain/repositories/device_repository.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:sat_east_client/features/course_map/data/datasources/course_map_remote_data_source.dart';
import 'package:sat_east_client/features/course_map/data/repositories/course_map_repository_impl.dart';
import 'package:sat_east_client/features/course_map/domain/repositories/course_map_repository.dart';
import 'package:sat_east_client/features/course_map/presentation/cubit/course_map_cubit.dart';
import 'package:sat_east_client/features/practice/data/datasources/practice_remote_data_source.dart';
import 'package:sat_east_client/features/practice/data/repositories/practice_repository_impl.dart';
import 'package:sat_east_client/features/practice/domain/repositories/practice_repository.dart';
import 'package:sat_east_client/features/practice/presentation/cubit/practice_cubit.dart';
import 'package:sat_east_client/features/topic/data/datasources/topic_remote_data_source.dart';
import 'package:sat_east_client/features/topic/data/repositories/topic_repository_impl.dart';
import 'package:sat_east_client/features/topic/domain/repositories/topic_repository.dart';
import 'package:sat_east_client/features/topic/presentation/cubit/topic_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final GetIt getIt = GetIt.instance;

/// Registers services and repositories as lazy singletons, cubits as
/// factories (ADR-007 §2). Features add their own `register*` calls here.
///
/// [errorReporter] and [analytics] are built in `main.dart` because they must
/// exist before the app starts (ADR-008). [deviceBox] is the opened Hive box
/// that persists the device id.
void configureDependencies({
  required ErrorReporter errorReporter,
  required AnalyticsService analytics,
  required Box<String> deviceBox,
}) {
  getIt
    ..registerLazySingleton<SupabaseClient>(() => Supabase.instance.client)
    ..registerSingleton<ErrorReporter>(errorReporter)
    ..registerSingleton<AnalyticsService>(analytics)
    // Auth and device registration (P1).
    ..registerLazySingleton<DeviceIdStore>(() => DeviceIdStore(deviceBox))
    ..registerLazySingleton<DeviceInfo>(DeviceInfo.new)
    ..registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSource(getIt<SupabaseClient>().auth),
    )
    ..registerLazySingleton<DeviceRemoteDataSource>(
      () => DeviceRemoteDataSource(
        (fn, params) => getIt<SupabaseClient>().rpc(fn, params: params),
      ),
    )
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(getIt<AuthRemoteDataSource>()),
    )
    ..registerLazySingleton<DeviceRepository>(
      () => DeviceRepositoryImpl(
        idStore: getIt<DeviceIdStore>(),
        info: getIt<DeviceInfo>(),
        remote: getIt<DeviceRemoteDataSource>(),
      ),
    )
    ..registerLazySingleton<CourseMapRemoteDataSource>(
      () => CourseMapRemoteDataSource(
        (fn, params) => getIt<SupabaseClient>().rpc(fn, params: params),
      ),
    )
    ..registerLazySingleton<CourseMapRepository>(
      () => CourseMapRepositoryImpl(getIt<CourseMapRemoteDataSource>()),
    )
    ..registerLazySingleton<PracticeRemoteDataSource>(
      () => PracticeRemoteDataSource(
        (fn, params) => getIt<SupabaseClient>().rpc(fn, params: params),
      ),
    )
    ..registerLazySingleton<PracticeRepository>(
      () => PracticeRepositoryImpl(getIt<PracticeRemoteDataSource>()),
    )
    ..registerFactory<PracticeCubit>(
      () => PracticeCubit(getIt<PracticeRepository>(), DateTime.now),
    )
    ..registerFactory<CourseMapCubit>(
      () => CourseMapCubit(getIt<CourseMapRepository>()),
    )
    ..registerLazySingleton<TopicRemoteDataSource>(
      () => TopicRemoteDataSource(
        (fn, params) => getIt<SupabaseClient>().rpc(fn, params: params),
      ),
    )
    ..registerLazySingleton<TopicRepository>(
      () => TopicRepositoryImpl(getIt<TopicRemoteDataSource>()),
    )
    ..registerFactory<TopicCubit>(
      () => TopicCubit(getIt<TopicRepository>()),
    )
    // Ruled exception to "cubits are factories": AuthCubit is app-wide
    // session state that the router also reads, so it must be one instance.
    ..registerLazySingleton<AuthCubit>(
      () => AuthCubit(
        getIt<AuthRepository>(),
        getIt<DeviceRepository>(),
        getIt<ErrorReporter>(),
      ),
    );
}
