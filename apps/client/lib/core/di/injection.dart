import 'package:get_it/get_it.dart';
import 'package:hive_ce/hive.dart';
import 'package:sat_east_client/core/analytics/analytics_service.dart';
import 'package:sat_east_client/core/observability/error_reporter.dart';
import 'package:sat_east_client/core/time/ticker.dart';
import 'package:sat_east_client/features/activation/data/datasources/activation_remote_data_source.dart';
import 'package:sat_east_client/features/activation/data/repositories/activation_repository_impl.dart';
import 'package:sat_east_client/features/activation/domain/repositories/activation_repository.dart';
import 'package:sat_east_client/features/activation/presentation/cubit/activation_cubit.dart';
import 'package:sat_east_client/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:sat_east_client/features/auth/data/datasources/device_id_store.dart';
import 'package:sat_east_client/features/auth/data/datasources/device_info.dart';
import 'package:sat_east_client/features/auth/data/datasources/device_remote_data_source.dart';
import 'package:sat_east_client/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:sat_east_client/features/auth/data/repositories/device_repository_impl.dart';
import 'package:sat_east_client/features/auth/domain/repositories/auth_repository.dart';
import 'package:sat_east_client/features/auth/domain/repositories/device_repository.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/account_cubit.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:sat_east_client/features/catalogue/data/datasources/catalogue_remote_data_source.dart';
import 'package:sat_east_client/features/catalogue/data/repositories/catalogue_repository_impl.dart';
import 'package:sat_east_client/features/catalogue/domain/repositories/catalogue_repository.dart';
import 'package:sat_east_client/features/catalogue/presentation/cubit/catalogue_cubit.dart';
import 'package:sat_east_client/features/catalogue/presentation/cubit/course_page_cubit.dart';
import 'package:sat_east_client/features/course_map/data/datasources/course_map_remote_data_source.dart';
import 'package:sat_east_client/features/course_map/data/repositories/course_map_repository_impl.dart';
import 'package:sat_east_client/features/course_map/domain/repositories/course_map_repository.dart';
import 'package:sat_east_client/features/course_map/presentation/cubit/course_map_cubit.dart';
import 'package:sat_east_client/features/notes/data/datasources/notes_remote_data_source.dart';
import 'package:sat_east_client/features/notes/data/repositories/notes_repository_impl.dart';
import 'package:sat_east_client/features/notes/domain/repositories/notes_repository.dart';
import 'package:sat_east_client/features/notes/presentation/cubit/notes_viewer_cubit.dart';
import 'package:sat_east_client/features/practice/data/datasources/practice_remote_data_source.dart';
import 'package:sat_east_client/features/practice/data/repositories/practice_repository_impl.dart';
import 'package:sat_east_client/features/practice/domain/repositories/practice_repository.dart';
import 'package:sat_east_client/features/practice/presentation/cubit/practice_cubit.dart';
import 'package:sat_east_client/features/quiz/data/datasources/quiz_remote_data_source.dart';
import 'package:sat_east_client/features/quiz/data/repositories/quiz_repository_impl.dart';
import 'package:sat_east_client/features/quiz/domain/repositories/quiz_repository.dart';
import 'package:sat_east_client/features/quiz/presentation/cubit/quiz_cubit.dart';
import 'package:sat_east_client/features/teacher/course_builder/data/datasources/course_builder_remote_data_source.dart';
import 'package:sat_east_client/features/teacher/course_builder/data/repositories/course_builder_repository_impl.dart';
import 'package:sat_east_client/features/teacher/course_builder/domain/repositories/course_builder_repository.dart';
import 'package:sat_east_client/features/teacher/course_builder/presentation/cubit/course_builder_cubit.dart';
import 'package:sat_east_client/features/teacher/notes/data/datasources/teacher_notes_remote_data_source.dart';
import 'package:sat_east_client/features/teacher/notes/data/repositories/teacher_notes_repository_impl.dart';
import 'package:sat_east_client/features/teacher/notes/data/services/pdfrx_page_counter.dart';
import 'package:sat_east_client/features/teacher/notes/domain/repositories/teacher_notes_repository.dart';
import 'package:sat_east_client/features/teacher/notes/domain/services/pdf_page_counter.dart';
import 'package:sat_east_client/features/teacher/notes/domain/usecases/teacher_notes_actions.dart';
import 'package:sat_east_client/features/teacher/notes/presentation/cubit/teacher_notes_cubit.dart';
import 'package:sat_east_client/features/teacher/questions/data/datasources/question_bank_remote_data_source.dart';
import 'package:sat_east_client/features/teacher/questions/data/datasources/question_editor_remote_data_source.dart';
import 'package:sat_east_client/features/teacher/questions/data/datasources/question_import_remote_data_source.dart';
import 'package:sat_east_client/features/teacher/questions/data/repositories/question_bank_repository_impl.dart';
import 'package:sat_east_client/features/teacher/questions/data/repositories/question_editor_repository_impl.dart';
import 'package:sat_east_client/features/teacher/questions/data/repositories/question_import_repository_impl.dart';
import 'package:sat_east_client/features/teacher/questions/data/services/bank_timer_scheduler.dart';
import 'package:sat_east_client/features/teacher/questions/data/services/file_picker.dart';
import 'package:sat_east_client/features/teacher/questions/domain/repositories/question_bank_repository.dart';
import 'package:sat_east_client/features/teacher/questions/domain/repositories/question_editor_repository.dart';
import 'package:sat_east_client/features/teacher/questions/domain/repositories/question_import_repository.dart';
import 'package:sat_east_client/features/teacher/questions/domain/services/file_picker_service.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_bank_cubit.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_editor_cubit.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_import_cubit.dart';
import 'package:sat_east_client/features/teacher/review/data/datasources/review_remote_data_source.dart';
import 'package:sat_east_client/features/teacher/review/data/repositories/review_repository_impl.dart';
import 'package:sat_east_client/features/teacher/review/domain/repositories/review_repository.dart';
import 'package:sat_east_client/features/teacher/review/domain/usecases/review_actions.dart';
import 'package:sat_east_client/features/teacher/review/presentation/cubit/review_counts_cubit.dart';
import 'package:sat_east_client/features/teacher/review/presentation/cubit/review_queue_cubit.dart';
import 'package:sat_east_client/features/teacher/review/presentation/cubit/review_reports_cubit.dart';
import 'package:sat_east_client/features/teacher/settings/data/datasources/teacher_settings_remote_data_source.dart';
import 'package:sat_east_client/features/teacher/settings/data/repositories/teacher_settings_repository_impl.dart';
import 'package:sat_east_client/features/teacher/settings/domain/repositories/teacher_settings_repository.dart';
import 'package:sat_east_client/features/teacher/settings/presentation/cubit/teacher_settings_cubit.dart';
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
      () => AuthRemoteDataSource(
        getIt<SupabaseClient>().auth,
        client: getIt<SupabaseClient>(),
      ),
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
    ..registerLazySingleton<QuizRemoteDataSource>(
      () => QuizRemoteDataSource(
        (fn, params) => getIt<SupabaseClient>().rpc(fn, params: params),
      ),
    )
    ..registerLazySingleton<QuizRepository>(
      () => QuizRepositoryImpl(getIt<QuizRemoteDataSource>()),
    )
    ..registerFactory<QuizCubit>(
      () => QuizCubit(getIt<QuizRepository>(), DateTime.now, defaultTicker),
    )
    ..registerLazySingleton<TopicRemoteDataSource>(
      () => TopicRemoteDataSource(
        (fn, params) => getIt<SupabaseClient>().rpc(fn, params: params),
      ),
    )
    ..registerLazySingleton<TopicRepository>(
      () => TopicRepositoryImpl(getIt<TopicRemoteDataSource>()),
    )
    ..registerFactory<TopicCubit>(() => TopicCubit(getIt<TopicRepository>()))
    // Ruled exception to "cubits are factories": AuthCubit is app-wide
    // session state that the router also reads, so it must be one instance.
    ..registerLazySingleton<AuthCubit>(
      () => AuthCubit(
        getIt<AuthRepository>(),
        getIt<DeviceRepository>(),
        getIt<ErrorReporter>(),
      ),
    )
    ..registerFactory<AccountCubit>(
      () => AccountCubit(getIt<AuthRepository>(), getIt<DeviceRepository>()),
    )
    ..registerLazySingleton<ActivationRemoteDataSource>(
      () => ActivationRemoteDataSource(
        (fn, params) => getIt<SupabaseClient>().rpc(fn, params: params),
      ),
    )
    ..registerLazySingleton<ActivationRepository>(
      () => ActivationRepositoryImpl(getIt<ActivationRemoteDataSource>()),
    )
    ..registerFactory<ActivationCubit>(
      () => ActivationCubit(getIt<ActivationRepository>()),
    )
    ..registerLazySingleton<CatalogueRemoteDataSource>(
      () => CatalogueRemoteDataSource(
        (fn, params) => getIt<SupabaseClient>().rpc(fn, params: params),
      ),
    )
    ..registerLazySingleton<CatalogueRepository>(
      () => CatalogueRepositoryImpl(getIt<CatalogueRemoteDataSource>()),
    )
    ..registerFactory<CatalogueCubit>(
      () => CatalogueCubit(getIt<CatalogueRepository>()),
    )
    ..registerFactory<CoursePageCubit>(
      () => CoursePageCubit(getIt<CatalogueRepository>()),
    )
    ..registerLazySingleton<CourseBuilderRemoteDataSource>(
      () => CourseBuilderRemoteDataSource(
        (fn, params) => getIt<SupabaseClient>().rpc(fn, params: params),
      ),
    )
    ..registerLazySingleton<CourseBuilderRepository>(
      () => CourseBuilderRepositoryImpl(getIt<CourseBuilderRemoteDataSource>()),
    )
    ..registerFactory<CourseBuilderCubit>(
      () => CourseBuilderCubit(getIt<CourseBuilderRepository>()),
    )
    ..registerLazySingleton<TeacherSettingsRemoteDataSource>(
      () => TeacherSettingsRemoteDataSource(
        (fn, params) => getIt<SupabaseClient>().rpc(fn, params: params),
      ),
    )
    ..registerLazySingleton<TeacherSettingsRepository>(
      () => TeacherSettingsRepositoryImpl(
        getIt<TeacherSettingsRemoteDataSource>(),
      ),
    )
    ..registerFactory<TeacherSettingsCubit>(
      () => TeacherSettingsCubit(getIt<TeacherSettingsRepository>()),
    )
    ..registerLazySingleton<FilePickerService>(createFilePicker)
    ..registerLazySingleton<QuestionImportRemoteDataSource>(
      () => QuestionImportRemoteDataSource(
        (fn, params) => getIt<SupabaseClient>().rpc(fn, params: params),
      ),
    )
    ..registerLazySingleton<QuestionImportRepository>(
      () =>
          QuestionImportRepositoryImpl(getIt<QuestionImportRemoteDataSource>()),
    )
    ..registerFactory<QuestionImportCubit>(
      () => QuestionImportCubit(
        getIt<QuestionImportRepository>(),
        getIt<FilePickerService>(),
      ),
    )
    ..registerLazySingleton<QuestionBankRemoteDataSource>(
      () => QuestionBankRemoteDataSource(
        (fn, params) => getIt<SupabaseClient>().rpc(fn, params: params),
      ),
    )
    ..registerLazySingleton<QuestionBankRepository>(
      () => QuestionBankRepositoryImpl(getIt<QuestionBankRemoteDataSource>()),
    )
    ..registerFactory<QuestionBankCubit>(
      () => QuestionBankCubit(
        getIt<QuestionBankRepository>(),
        schedule: scheduleBankSearch,
      ),
    )
    ..registerLazySingleton<QuestionEditorRemoteDataSource>(
      () => QuestionEditorRemoteDataSource(
        (fn, params) => getIt<SupabaseClient>().rpc(fn, params: params),
      ),
    )
    ..registerLazySingleton<QuestionEditorRepository>(
      () =>
          QuestionEditorRepositoryImpl(getIt<QuestionEditorRemoteDataSource>()),
    )
    ..registerFactory<QuestionEditorCubit>(
      () => QuestionEditorCubit(
        getIt<QuestionEditorRepository>(),
        getIt<QuestionBankRepository>(),
      ),
    )
    ..registerLazySingleton<NotesRemoteDataSource>(
      () => NotesRemoteDataSource(
        (path) => getIt<SupabaseClient>().storage.from('notes').download(path),
        (fn, params) => getIt<SupabaseClient>().rpc(fn, params: params),
      ),
    )
    ..registerLazySingleton<NotesRepository>(
      () => NotesRepositoryImpl(getIt<NotesRemoteDataSource>()),
    )
    ..registerFactory<NotesViewerCubit>(
      () => NotesViewerCubit(
        getIt<NotesRepository>(),
        getIt<AuthRepository>(),
        DateTime.now,
      ),
    )
    ..registerLazySingleton<TeacherNotesRemoteDataSource>(
      () => TeacherNotesRemoteDataSource(
        rpc: (fn, params) => getIt<SupabaseClient>().rpc(fn, params: params),
        readNotes: (topicId) => getIt<SupabaseClient>()
            .from('topic_assets')
            .select('id,title,subtopic_id,page_count,ready')
            .eq('topic_id', topicId)
            .eq('kind', 'notes')
            .order('sort')
            .order('id'),
        readLimit: () => getIt<SupabaseClient>()
            .from('settings')
            .select('value')
            .eq('key', 'notes_max_mb')
            .single(),
        uploadBytes: (path, bytes) async {
          await getIt<SupabaseClient>().storage
              .from('notes')
              .uploadBinary(
                path,
                bytes,
                fileOptions: const FileOptions(contentType: 'application/pdf'),
              );
        },
        removeObject: (path) async {
          await getIt<SupabaseClient>().storage.from('notes').remove([path]);
        },
      ),
    )
    ..registerLazySingleton<TeacherNotesRepository>(
      () => TeacherNotesRepositoryImpl(getIt<TeacherNotesRemoteDataSource>()),
    )
    ..registerLazySingleton<PdfPageCounter>(PdfrxPageCounter.new)
    ..registerLazySingleton<TeacherNotesActions>(
      () => TeacherNotesActions(
        getIt<TeacherNotesRepository>(),
        getIt<QuestionBankRepository>(),
        getIt<FilePickerService>(),
        getIt<PdfPageCounter>(),
      ),
    )
    ..registerFactory<TeacherNotesCubit>(
      () => TeacherNotesCubit(getIt<TeacherNotesActions>()),
    )
    ..registerLazySingleton<ReviewRemoteDataSource>(
      () => ReviewRemoteDataSource(
        (fn, params) => getIt<SupabaseClient>().rpc(fn, params: params),
      ),
    )
    ..registerLazySingleton<ReviewRepository>(
      () => ReviewRepositoryImpl(getIt<ReviewRemoteDataSource>()),
    )
    ..registerLazySingleton<ReviewActions>(
      () => ReviewActions(getIt<ReviewRepository>()),
    )
    ..registerFactory<ReviewQueueCubit>(
      () => ReviewQueueCubit(getIt<ReviewActions>()),
    )
    ..registerFactory<ReviewReportsCubit>(
      () => ReviewReportsCubit(getIt<ReviewActions>()),
    )
    ..registerFactory<ReviewCountsCubit>(
      () => ReviewCountsCubit(getIt<ReviewActions>()),
    );
}
