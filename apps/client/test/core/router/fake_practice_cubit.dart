import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/features/practice/domain/entities/practice.dart';
import 'package:sat_east_client/features/practice/presentation/cubit/practice_cubit.dart';
import 'package:sat_east_client/features/practice/presentation/cubit/practice_state.dart';

class _FakePracticeCubit extends MockCubit<PracticeState>
    implements PracticeCubit {}

Future<void> registerFakePracticeCubit({PracticeState? state}) async {
  await unregisterFakePracticeCubit();
  getIt.registerFactory<PracticeCubit>(() {
    final cubit = _FakePracticeCubit();
    whenListen(
      cubit,
      const Stream<PracticeState>.empty(),
      initialState:
          state ??
          const PracticeInProgress(
            set: PracticeSet(
              attemptId: 'attempt',
              repTarget: 1,
              questions: [
                PracticeQuestion(
                  id: 'question',
                  kind: PracticeKind.mcq,
                  difficulty: 'E',
                  stemMd: 'Solve the equation.',
                  choices: [
                    PracticeChoice('A', 'One'),
                    PracticeChoice('B', 'Two'),
                  ],
                ),
              ],
            ),
            index: 0,
          ),
    );
    when(() => cubit.start(any())).thenAnswer((_) async {});
    when(cubit.close).thenAnswer((_) async {});
    return cubit;
  });
}

Future<void> unregisterFakePracticeCubit() async {
  if (getIt.isRegistered<PracticeCubit>()) {
    await getIt.unregister<PracticeCubit>();
  }
}
