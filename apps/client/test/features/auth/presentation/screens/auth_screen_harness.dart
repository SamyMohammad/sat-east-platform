import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_state.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

class MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

/// Viewports every screen is checked at.
const viewports = <(String, Size)>[
  ('360x800', Size(360, 800)),
  ('1280x800', Size(1280, 800)),
];

final _paths = [
  AppRoutes.signIn,
  AppRoutes.signUp,
  AppRoutes.checkInbox,
  AppRoutes.devices,
];

/// A mock cubit that reports [state] and accepts every command.
MockAuthCubit mockCubit(AuthState state) {
  final cubit = MockAuthCubit();
  whenListen(cubit, const Stream<AuthState>.empty(), initialState: state);
  when(() => cubit.signIn(any(), any())).thenAnswer((_) async {});
  when(() => cubit.signUp(any(), any(), any())).thenAnswer((_) async {});
  when(() => cubit.removeDevice(any())).thenAnswer((_) async {});
  when(cubit.signOut).thenAnswer((_) async {});
  return cubit;
}

/// Pumps [screen] at [path] inside a tiny router so `context.go` works.
/// Other paths render `route:<path>` placeholders.
Future<void> pumpAuthScreen(
  WidgetTester tester, {
  required MockAuthCubit cubit,
  required Widget screen,
  required String path,
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: path,
    routes: [
      for (final p in _paths)
        GoRoute(
          path: p,
          builder: (context, state) =>
              p == path ? screen : Scaffold(body: Text('route:$p')),
        ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    BlocProvider<AuthCubit>.value(
      value: cubit,
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// The [LoadingButton] whose label equals [label].
Finder loadingButton(String label) => find.byWidgetPredicate(
  (w) => w is LoadingButton && w.label == label,
  description: 'LoadingButton "$label"',
);

/// The [LoadingButton] whose label starts with [prefix].
Finder loadingButtonStartingWith(String prefix) => find.byWidgetPredicate(
  (w) => w is LoadingButton && w.label.startsWith(prefix),
  description: 'LoadingButton starting with "$prefix"',
);

LoadingButton buttonOf(WidgetTester tester, Finder finder) =>
    tester.widget<LoadingButton>(finder);
