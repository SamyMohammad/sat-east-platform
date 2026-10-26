import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/theme/theme_mode_cubit.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/account_cubit.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/account_state.dart';

class _Theme extends MockCubit<ThemeMode> implements ThemeModeCubit {}

class _Account extends MockCubit<AccountState> implements AccountCubit {}

Future<void> registerFakeAccountCubit() async {
  await unregisterFakeAccountCubit();
  final theme = _Theme();
  whenListen(
    theme,
    const Stream<ThemeMode>.empty(),
    initialState: ThemeMode.system,
  );
  getIt
    ..registerSingleton<ThemeModeCubit>(theme)
    ..registerFactory<AccountCubit>(() {
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
  if (getIt.isRegistered<ThemeModeCubit>()) {
    await getIt.unregister<ThemeModeCubit>();
  }
  if (getIt.isRegistered<AccountCubit>()) {
    await getIt.unregister<AccountCubit>();
  }
}
