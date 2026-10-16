import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/router/auth_refresh.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/auth/domain/entities/app_user.dart';
import 'package:sat_east_client/features/auth/domain/entities/device.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_state.dart';
import 'package:sat_east_client/features/design_gallery/presentation/gallery_screen.dart';

import '../../features/auth/presentation/screens/auth_screen_harness.dart';

const _user = AppUser(id: 'u1', email: 'a@b.co');
const _device = Device(id: 'd1', platform: 'web', label: 'Chrome on Windows');

const _unknown = AuthUnknown();
const _busy = AuthBusy();
const _signedOut = AuthSignedOut();
const _confirmation = AuthConfirmationSent('a@b.co');
const _gate = AuthDeviceGate(devices: [_device], changesLeft: 1);
const _signedIn = AuthSignedIn(_user);

/// A mock cubit whose state and stream can change during a test.
class _Harness {
  _Harness(AuthState initial) : current = initial {
    cubit = mockCubit(initial);
    when(() => cubit.state).thenAnswer((_) => current);
    when(() => cubit.stream).thenAnswer((_) => _controller.stream);
  }

  late final MockAuthCubit cubit;
  AuthState current;
  final _controller = StreamController<AuthState>.broadcast();

  void emit(AuthState state) {
    current = state;
    _controller.add(state);
  }

  Future<void> close() => _controller.close();
}

Future<void> _pumpFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

String _path(GoRouter router) => router.routeInformationProvider.value.uri.path;

Future<GoRouter> _pump(
  WidgetTester tester,
  _Harness harness,
  String location,
  double width, {
  bool includeGallery = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 800);
  addTearDown(tester.view.reset);
  final router = createRouter(
    initialLocation: location,
    includeGallery: includeGallery,
    auth: harness.cubit,
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    await harness.close();
  });
  await tester.pumpWidget(
    BlocProvider<AuthCubit>.value(
      value: harness.cubit,
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  await _pumpFrames(tester);
  return router;
}

void main() {
  // (state, start location, expected location)
  final rules = <(String, AuthState, String, String)>[
    ('Unknown stays on /', _unknown, AppRoutes.home, AppRoutes.home),
    (
      'Unknown stays on /sign-in',
      _unknown,
      AppRoutes.signIn,
      AppRoutes.signIn,
    ),
    ('Busy stays on /courses', _busy, AppRoutes.courses, AppRoutes.courses),
    ('Busy stays on /sign-in', _busy, AppRoutes.signIn, AppRoutes.signIn),
    ('SignedOut / -> sign-in', _signedOut, AppRoutes.home, AppRoutes.signIn),
    (
      'SignedOut /courses -> sign-in',
      _signedOut,
      AppRoutes.courses,
      AppRoutes.signIn,
    ),
    (
      'SignedOut stays on /sign-in',
      _signedOut,
      AppRoutes.signIn,
      AppRoutes.signIn,
    ),
    (
      'SignedOut stays on /sign-up',
      _signedOut,
      AppRoutes.signUp,
      AppRoutes.signUp,
    ),
    (
      'SignedOut /check-inbox -> sign-in',
      _signedOut,
      AppRoutes.checkInbox,
      AppRoutes.signIn,
    ),
    (
      'SignedOut /devices -> sign-in',
      _signedOut,
      AppRoutes.devices,
      AppRoutes.signIn,
    ),
    (
      'ConfirmationSent / -> check-inbox',
      _confirmation,
      AppRoutes.home,
      AppRoutes.checkInbox,
    ),
    (
      'ConfirmationSent /sign-in -> check-inbox',
      _confirmation,
      AppRoutes.signIn,
      AppRoutes.checkInbox,
    ),
    (
      'ConfirmationSent stays on /check-inbox',
      _confirmation,
      AppRoutes.checkInbox,
      AppRoutes.checkInbox,
    ),
    ('DeviceGate / -> devices', _gate, AppRoutes.home, AppRoutes.devices),
    (
      'DeviceGate /sign-in -> devices',
      _gate,
      AppRoutes.signIn,
      AppRoutes.devices,
    ),
    (
      'DeviceGate stays on /devices',
      _gate,
      AppRoutes.devices,
      AppRoutes.devices,
    ),
    (
      'SignedIn /sign-in -> home',
      _signedIn,
      AppRoutes.signIn,
      AppRoutes.home,
    ),
    (
      'SignedIn /sign-up -> home',
      _signedIn,
      AppRoutes.signUp,
      AppRoutes.home,
    ),
    (
      'SignedIn /check-inbox -> home',
      _signedIn,
      AppRoutes.checkInbox,
      AppRoutes.home,
    ),
    (
      'SignedIn /devices -> home',
      _signedIn,
      AppRoutes.devices,
      AppRoutes.home,
    ),
    ('SignedIn stays on /', _signedIn, AppRoutes.home, AppRoutes.home),
    (
      'SignedIn stays on /courses',
      _signedIn,
      AppRoutes.courses,
      AppRoutes.courses,
    ),
  ];

  for (final width in [360.0, 1280.0]) {
    group('P1-2: auth redirect at $width', () {
      for (final (title, state, start, expected) in rules) {
        testWidgets('P1-2: $title', (tester) async {
          final router = await _pump(tester, _Harness(state), start, width);

          expect(_path(router), expected);
          expect(tester.takeException(), isNull);
        });
      }
    });
  }

  group('P1-2: auth redirect has no loop', () {
    testWidgets('P1-2: signed in at /sign-in lands on / and stays', (
      tester,
    ) async {
      final router = await _pump(
        tester,
        _Harness(_signedIn),
        AppRoutes.signIn,
        1280,
      );
      await _pumpFrames(tester);

      expect(_path(router), AppRoutes.home);
      expect(tester.takeException(), isNull);
    });

    testWidgets('P1-2: signed out at / lands on /sign-in and stays', (
      tester,
    ) async {
      final router = await _pump(
        tester,
        _Harness(_signedOut),
        AppRoutes.home,
        1280,
      );
      await _pumpFrames(tester);

      expect(_path(router), AppRoutes.signIn);
      expect(tester.takeException(), isNull);
    });
  });

  group('P1-2: /gallery is exempt from redirects', () {
    final states = <String, AuthState>{
      'signed out': _signedOut,
      'confirmation sent': _confirmation,
      'device gate': _gate,
    };
    for (final entry in states.entries) {
      testWidgets('P1-2: reachable while ${entry.key}', (tester) async {
        final router = await _pump(
          tester,
          _Harness(entry.value),
          AppRoutes.gallery,
          1280,
          includeGallery: true,
        );

        expect(_path(router), AppRoutes.gallery);
        expect(find.byType(GalleryScreen), findsOneWidget);
      });
    }
  });

  group('P1-2: auth state changes refresh the router', () {
    testWidgets('P1-2: sign in moves /sign-in to /', (tester) async {
      final harness = _Harness(_signedOut);
      final router = await _pump(tester, harness, AppRoutes.signIn, 1280);
      expect(_path(router), AppRoutes.signIn);

      harness.emit(_signedIn);
      await _pumpFrames(tester);

      expect(_path(router), AppRoutes.home);
    });

    testWidgets('P1-2: sign out moves / to /sign-in', (tester) async {
      final harness = _Harness(_signedIn);
      final router = await _pump(tester, harness, AppRoutes.home, 1280);
      expect(_path(router), AppRoutes.home);

      harness.emit(_signedOut);
      await _pumpFrames(tester);

      expect(_path(router), AppRoutes.signIn);
    });

    testWidgets('P1-2: device limit moves /sign-in to /devices', (
      tester,
    ) async {
      final harness = _Harness(_signedOut);
      final router = await _pump(tester, harness, AppRoutes.signIn, 1280);

      harness.emit(_gate);
      await _pumpFrames(tester);

      expect(_path(router), AppRoutes.devices);
    });

    testWidgets('P1-2: confirmation sent moves /sign-up to /check-inbox', (
      tester,
    ) async {
      final harness = _Harness(_signedOut);
      final router = await _pump(tester, harness, AppRoutes.signUp, 1280);
      expect(_path(router), AppRoutes.signUp);

      harness.emit(_confirmation);
      await _pumpFrames(tester);

      expect(_path(router), AppRoutes.checkInbox);
    });

    testWidgets('P1-2: Busy does not move the user', (tester) async {
      final harness = _Harness(_signedOut);
      final router = await _pump(tester, harness, AppRoutes.signUp, 1280);

      harness.emit(_busy);
      await _pumpFrames(tester);

      expect(_path(router), AppRoutes.signUp);
    });
  });

  group('P1-2: GoRouterRefreshStream', () {
    test('P1-2: notifies once per stream event', () async {
      final controller = StreamController<int>.broadcast();
      addTearDown(controller.close);
      final notifier = GoRouterRefreshStream(controller.stream);
      addTearDown(notifier.dispose);
      var count = 0;
      notifier.addListener(() => count++);

      controller
        ..add(1)
        ..add(2);
      await pumpEventQueue();

      expect(count, 2);
    });

    test('P1-2: cancels its subscription on dispose', () async {
      final controller = StreamController<int>.broadcast();
      addTearDown(controller.close);
      final notifier = GoRouterRefreshStream(controller.stream);
      var count = 0;
      notifier.addListener(() => count++);
      expect(controller.hasListener, isTrue);

      notifier.dispose();
      controller.add(1);
      await pumpEventQueue();

      expect(controller.hasListener, isFalse);
      expect(count, 0);
    });
  });
}
