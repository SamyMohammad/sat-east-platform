part of 'app_router_test.dart';

class FakeQuizCubit extends MockCubit<QuizState> implements QuizCubit {}

Future<void> registerFakeQuizCubit({
  QuizState? state,
  void Function(String)? onStart,
}) async {
  await unregisterFakeQuizCubit();
  getIt.registerFactory<QuizCubit>(() {
    final cubit = FakeQuizCubit();
    whenListen(
      cubit,
      const Stream<QuizState>.empty(),
      initialState:
          state ?? const QuizFailed(AppError(ErrorCodes.practiceNeeded)),
    );
    when(() => cubit.start(any())).thenAnswer((invocation) async {
      onStart?.call(invocation.positionalArguments.single as String);
    });
    when(cubit.close).thenAnswer((_) async {});
    return cubit;
  });
}

Future<void> unregisterFakeQuizCubit() async {
  if (getIt.isRegistered<QuizCubit>()) await getIt.unregister<QuizCubit>();
}
