import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/features/mock/presentation/cubit/mock_hub_cubit.dart';
import 'package:sat_east_client/features/mock/presentation/cubit/mock_hub_state.dart';

class _FakeMockHubCubit extends MockCubit<MockHubState>
    implements MockHubCubit {}

void registerFakeMockHubCubit() {
  getIt.registerFactory<MockHubCubit>(() {
    final cubit = _FakeMockHubCubit();
    whenListen(
      cubit,
      const Stream<MockHubState>.empty(),
      initialState: const MockHubLoading(),
    );
    when(cubit.load).thenAnswer((_) async {});
    when(cubit.retry).thenAnswer((_) async {});
    when(cubit.close).thenAnswer((_) async {});
    return cubit;
  });
}

Future<void> unregisterFakeMockHubCubit() async {
  await getIt.unregister<MockHubCubit>();
}
