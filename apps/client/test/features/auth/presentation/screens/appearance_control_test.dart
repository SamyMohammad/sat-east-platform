import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/observability/error_reporter.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/core/theme/theme_mode_cubit.dart';
import 'package:sat_east_client/core/theme/theme_mode_store.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/account_cubit.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/account_state.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_state.dart';
import 'package:sat_east_client/features/auth/presentation/screens/account_screen.dart';

import 'auth_screen_harness.dart';

class _Account extends MockCubit<AccountState> implements AccountCubit {}

class _Box extends Mock implements Box<String> {}

void main() {
  for (final state in <AccountState>[
    const AccountLoading(),
    const AccountError(AppError(ErrorCodes.network)),
  ]) {
    testWidgets(
      'appearance_control_switches_theme during ${state.runtimeType}',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final account = _Account();
        whenListen(
          account,
          const Stream<AccountState>.empty(),
          initialState: state,
        );
        final box = _Box();
        String? stored;
        when(() => box.get('themeMode')).thenAnswer((_) => stored);
        when(() => box.put('themeMode', any())).thenAnswer((invocation) async {
          stored = invocation.positionalArguments[1] as String;
        });
        final theme = ThemeModeCubit(
          ThemeModeStore(box, const NoopErrorReporter()),
        );
        getIt.registerSingleton<ThemeModeCubit>(theme);
        addTearDown(() async {
          await getIt.unregister<ThemeModeCubit>();
          await theme.close();
        });
        final auth = mockCubit(const AuthSignedOut());
        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider<AccountCubit>.value(value: account),
              BlocProvider<AuthCubit>.value(value: auth),
            ],
            child: BlocBuilder<ThemeModeCubit, ThemeMode>(
              bloc: theme,
              builder: (context, mode) => MaterialApp(
                theme: AppTheme.light(),
                darkTheme: AppTheme.dark(),
                themeMode: mode,
                home: const Scaffold(body: AccountView()),
              ),
            ),
          ),
        );
        expect(find.text('Appearance'), findsOneWidget);
        for (final mode in [
          ThemeMode.dark,
          ThemeMode.light,
          ThemeMode.system,
        ]) {
          final label = switch (mode) {
            ThemeMode.dark => 'Dark',
            ThemeMode.light => 'Light',
            ThemeMode.system => 'System',
          };
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
          expect(theme.state, mode);
          expect(stored, mode.name);
          if (mode != ThemeMode.system) {
            expect(
              Theme.of(tester.element(find.byType(AccountView))).brightness,
              mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
            );
          }
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
