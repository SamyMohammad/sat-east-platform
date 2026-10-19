import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/account_cubit.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/account_state.dart';

class _Account extends MockCubit<AccountState> implements AccountCubit {}

Future<void> registerFakeAccountCubit() async {
  await unregisterFakeAccountCubit();
  getIt.registerFactory<AccountCubit>(() {
    final cubit = _Account();
    whenListen(
      cubit,
      const Stream<AccountState>.empty(),
      initialState: const AccountLoading(),
    );
    when(cubit.load).thenAnswer((_) async {});
    when(cubit.close).thenAnswer((_) async {});
    return cubit;
  });
}

Future<void> unregisterFakeAccountCubit() async {
  if (getIt.isRegistered<AccountCubit>()) {
    await getIt.unregister<AccountCubit>();
  }
}
