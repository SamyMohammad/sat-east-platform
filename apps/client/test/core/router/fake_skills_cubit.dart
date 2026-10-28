import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/features/skills/presentation/cubit/skills_cubit.dart';
import 'package:sat_east_client/features/skills/presentation/cubit/skills_state.dart';

class _FakeSkillsCubit extends MockCubit<SkillsState> implements SkillsCubit {}

void registerFakeSkillsCubit() {
  getIt.registerFactory<SkillsCubit>(() {
    final cubit = _FakeSkillsCubit();
    whenListen(
      cubit,
      const Stream<SkillsState>.empty(),
      initialState: const SkillsLoading(),
    );
    when(cubit.load).thenAnswer((_) async {});
    when(cubit.retry).thenAnswer((_) async {});
    when(cubit.close).thenAnswer((_) async {});
    return cubit;
  });
}

Future<void> unregisterFakeSkillsCubit() async {
  await getIt.unregister<SkillsCubit>();
}
