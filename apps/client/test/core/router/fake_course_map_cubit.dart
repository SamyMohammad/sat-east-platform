import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/features/course_map/presentation/cubit/course_map_cubit.dart';
import 'package:sat_east_client/features/course_map/presentation/cubit/course_map_state.dart';

class _FakeCourseMapCubit extends MockCubit<CourseMapState>
    implements CourseMapCubit {}

/// Registers a loading [CourseMapCubit] fake so router tests that render
/// `/courses` resolve it from `getIt`. Pair with [unregisterFakeCourseMapCubit].
Future<void> registerFakeCourseMapCubit() async {
  await unregisterFakeCourseMapCubit();
  getIt.registerFactory<CourseMapCubit>(() {
    final cubit = _FakeCourseMapCubit();
    whenListen(
      cubit,
      const Stream<CourseMapState>.empty(),
      initialState: const CourseMapLoading(),
    );
    when(cubit.load).thenAnswer((_) async {});
    when(cubit.close).thenAnswer((_) async {});
    return cubit;
  });
}

Future<void> unregisterFakeCourseMapCubit() async {
  if (getIt.isRegistered<CourseMapCubit>()) {
    await getIt.unregister<CourseMapCubit>();
  }
}
