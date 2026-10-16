import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/observability/error_reporter.dart';
import 'package:sat_east_client/features/auth/domain/entities/app_user.dart';
import 'package:sat_east_client/features/auth/domain/entities/device.dart';
import 'package:sat_east_client/features/auth/domain/entities/device_registration.dart';
import 'package:sat_east_client/features/auth/domain/entities/device_status.dart';
import 'package:sat_east_client/features/auth/domain/entities/sign_up_outcome.dart';
import 'package:sat_east_client/features/auth/domain/repositories/auth_repository.dart';
import 'package:sat_east_client/features/auth/domain/repositories/device_repository.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_state.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockDeviceRepository extends Mock implements DeviceRepository {}

class MockErrorReporter extends Mock implements ErrorReporter {}

const _user = AppUser(id: 'u1', email: 'a@b.co');
const _device = Device(id: 'd1', platform: 'web', label: 'Chrome on Windows');
const _limit = DeviceLimitReached(devices: [_device], changesLeft: 1);
const _allowed = DeviceAllowed('d1');
const _invalid = AppError(ErrorCodes.invalidCredentials);
const _network = AppError(ErrorCodes.network);
const _deviceLimitError = AppError(ErrorCodes.deviceLimit);
const _forbidden = AppError(ErrorCodes.forbidden);

const _gate = AuthDeviceGate(devices: [_device], changesLeft: 1);

void main() {
  late MockAuthRepository auth;
  late MockDeviceRepository devices;
  late MockErrorReporter reporter;
  late StreamController<void> ticks;

  setUp(() {
    auth = MockAuthRepository();
    devices = MockDeviceRepository();
    reporter = MockErrorReporter();
    ticks = StreamController<void>.broadcast();
    addTearDown(ticks.close);

    when(() => auth.currentUser).thenReturn(_user);
    when(() => auth.signOut()).thenAnswer((_) async => const Success(null));
    when(() => reporter.setUser(any())).thenAnswer((_) async {});
    when(() => reporter.clearUser()).thenAnswer((_) async {});
    when(
      () => devices.register(),
    ).thenAnswer((_) async => const Success(_allowed));
  });

  AuthCubit build() =>
      AuthCubit(auth, devices, reporter, ticker: (_) => ticks.stream);

  group('P1-2: start', () {
    blocTest<AuthCubit, AuthState>(
      'P1-2: emits SignedOut when there is no current user',
      setUp: () => when(() => auth.currentUser).thenReturn(null),
      build: build,
      act: (c) => c.start(),
      expect: () => [const AuthSignedOut()],
    );

    blocTest<AuthCubit, AuthState>(
      'P1-2: emits Busy then SignedIn when the device is allowed',
      build: build,
      act: (c) => c.start(),
      expect: () => [const AuthBusy(), const AuthSignedIn(_user)],
    );

    blocTest<AuthCubit, AuthState>(
      'P1-2: emits Busy then DeviceGate when the limit is reached',
      setUp: () => when(
        () => devices.register(),
      ).thenAnswer((_) async => const Success(_limit)),
      build: build,
      act: (c) => c.start(),
      expect: () => [const AuthBusy(), _gate],
    );

    blocTest<AuthCubit, AuthState>(
      'P1-2: emits SignedOut with the error when register fails',
      setUp: () => when(
        () => devices.register(),
      ).thenAnswer((_) async => const Failure(_network)),
      build: build,
      act: (c) => c.start(),
      expect: () => [const AuthBusy(), const AuthSignedOut(error: _network)],
    );

    blocTest<AuthCubit, AuthState>(
      'P1-2: reports the user id (never the email) on SignedIn',
      build: build,
      act: (c) => c.start(),
      verify: (_) {
        verify(() => reporter.setUser('u1')).called(1);
        verifyNever(() => reporter.setUser('a@b.co'));
      },
    );
  });

  group('P1-2: signIn', () {
    setUp(() {
      when(
        () => auth.signIn(email: 'a@b.co', password: 'pw'),
      ).thenAnswer((_) async => const Success(_user));
    });

    blocTest<AuthCubit, AuthState>(
      'P1-2: emits Busy then SignedIn on success',
      build: build,
      act: (c) => c.signIn('a@b.co', 'pw'),
      expect: () => [const AuthBusy(), const AuthSignedIn(_user)],
    );

    blocTest<AuthCubit, AuthState>(
      'P1-2: emits Busy then DeviceGate when the limit is reached',
      setUp: () => when(
        () => devices.register(),
      ).thenAnswer((_) async => const Success(_limit)),
      build: build,
      act: (c) => c.signIn('a@b.co', 'pw'),
      expect: () => [const AuthBusy(), _gate],
    );

    blocTest<AuthCubit, AuthState>(
      'P1-2: emits SignedOut with the error when sign in fails',
      setUp: () => when(
        () => auth.signIn(email: 'a@b.co', password: 'pw'),
      ).thenAnswer((_) async => const Failure(_invalid)),
      build: build,
      act: (c) => c.signIn('a@b.co', 'pw'),
      expect: () => [const AuthBusy(), const AuthSignedOut(error: _invalid)],
      verify: (_) => verifyNever(() => devices.register()),
    );

    blocTest<AuthCubit, AuthState>(
      'P1-2: emits SignedOut with the error when register fails',
      setUp: () => when(
        () => devices.register(),
      ).thenAnswer((_) async => const Failure(_network)),
      build: build,
      act: (c) => c.signIn('a@b.co', 'pw'),
      expect: () => [const AuthBusy(), const AuthSignedOut(error: _network)],
    );

    test(
      'P1-2: a double signIn while busy makes one repository call',
      () async {
        final pending = Completer<Result<AppUser>>();
        when(
          () => auth.signIn(email: 'a@b.co', password: 'pw'),
        ).thenAnswer((_) => pending.future);
        final cubit = build();
        addTearDown(cubit.close);

        final first = cubit.signIn('a@b.co', 'pw');
        final second = cubit.signIn('a@b.co', 'pw');
        pending.complete(const Success(_user));
        await Future.wait([first, second]);

        verify(() => auth.signIn(email: 'a@b.co', password: 'pw')).called(1);
        verify(() => devices.register()).called(1);
        expect(cubit.state, const AuthSignedIn(_user));
      },
    );
  });

  group('P1-2: signUp', () {
    blocTest<AuthCubit, AuthState>(
      'P1-2: emits ConfirmationSent with the email',
      setUp: () => when(
        () => auth.signUp(
          email: 'a@b.co',
          password: 'pw',
          fullName: 'Sam Ali',
        ),
      ).thenAnswer((_) async => const Success(SignUpOutcome.confirmationSent)),
      build: build,
      act: (c) => c.signUp('a@b.co', 'pw', 'Sam Ali'),
      expect: () => [
        const AuthBusy(),
        const AuthConfirmationSent('a@b.co'),
      ],
      verify: (_) => verifyNever(() => devices.register()),
    );

    blocTest<AuthCubit, AuthState>(
      'P1-2: registers the device when sign up signs in',
      setUp: () {
        when(
          () => auth.signUp(
            email: 'a@b.co',
            password: 'pw',
            fullName: 'Sam Ali',
          ),
        ).thenAnswer((_) async => const Success(SignUpOutcome.signedIn));
      },
      build: build,
      act: (c) => c.signUp('a@b.co', 'pw', 'Sam Ali'),
      expect: () => [const AuthBusy(), const AuthSignedIn(_user)],
    );

    blocTest<AuthCubit, AuthState>(
      'P1-2: emits SignedOut with the error when sign up fails',
      setUp: () =>
          when(
            () => auth.signUp(
              email: 'a@b.co',
              password: 'pw',
              fullName: 'Sam Ali',
            ),
          ).thenAnswer(
            (_) async => const Failure(AppError(ErrorCodes.emailTaken)),
          ),
      build: build,
      act: (c) => c.signUp('a@b.co', 'pw', 'Sam Ali'),
      expect: () => [
        const AuthBusy(),
        const AuthSignedOut(error: AppError(ErrorCodes.emailTaken)),
      ],
    );
  });

  group('P1-2: removeDevice', () {
    blocTest<AuthCubit, AuthState>(
      'P1-2: emits removing gate first, then re-registers on success',
      setUp: () => when(
        () => devices.remove('d1'),
      ).thenAnswer((_) async => const Success(0)),
      build: build,
      seed: () => _gate,
      act: (c) => c.removeDevice('d1'),
      expect: () => [
        const AuthDeviceGate(
          devices: [_device],
          changesLeft: 1,
          removing: true,
        ),
        const AuthSignedIn(_user),
      ],
      verify: (c) {
        verify(() => devices.remove('d1')).called(1);
        verify(() => devices.register()).called(1);
        expect(c.state, const AuthSignedIn(_user));
      },
    );

    blocTest<AuthCubit, AuthState>(
      'P1-2: shows the gate with changesLeft 0 on device_limit',
      setUp: () => when(
        () => devices.remove('d1'),
      ).thenAnswer((_) async => const Failure(_deviceLimitError)),
      build: build,
      seed: () => _gate,
      act: (c) => c.removeDevice('d1'),
      expect: () => [
        const AuthDeviceGate(
          devices: [_device],
          changesLeft: 1,
          removing: true,
        ),
        const AuthDeviceGate(
          devices: [_device],
          changesLeft: 0,
          error: _deviceLimitError,
        ),
      ],
      verify: (_) => verifyNever(() => devices.register()),
    );

    blocTest<AuthCubit, AuthState>(
      'P1-2: shows the gate with the error on any other failure',
      setUp: () => when(
        () => devices.remove('d1'),
      ).thenAnswer((_) async => const Failure(_forbidden)),
      build: build,
      seed: () => _gate,
      act: (c) => c.removeDevice('d1'),
      expect: () => [
        const AuthDeviceGate(
          devices: [_device],
          changesLeft: 1,
          removing: true,
        ),
        const AuthDeviceGate(
          devices: [_device],
          changesLeft: 1,
          error: _forbidden,
        ),
      ],
    );
  });

  group('P1-2: checkDevice', () {
    blocTest<AuthCubit, AuthState>(
      'P1-2: signs out with deviceRemoved when revoked',
      setUp: () => when(
        () => devices.status(),
      ).thenAnswer((_) async => const Success(DeviceStatus.revoked)),
      build: build,
      seed: () => const AuthSignedIn(_user),
      act: (c) => c.checkDevice(),
      expect: () => [
        const AuthSignedOut(reason: SignOutReason.deviceRemoved),
      ],
      verify: (_) {
        verify(() => auth.signOut()).called(1);
        verify(() => reporter.clearUser()).called(1);
      },
    );

    blocTest<AuthCubit, AuthState>(
      'P1-2: registers again when the status is unknown',
      setUp: () => when(
        () => devices.status(),
      ).thenAnswer((_) async => const Success(DeviceStatus.unknown)),
      build: build,
      seed: () => const AuthSignedIn(_user),
      act: (c) => c.checkDevice(),
      verify: (c) {
        verify(() => devices.register()).called(1);
        expect(c.state, const AuthSignedIn(_user));
      },
    );

    blocTest<AuthCubit, AuthState>(
      'P1-2: does nothing when the device is active',
      setUp: () => when(
        () => devices.status(),
      ).thenAnswer((_) async => const Success(DeviceStatus.active)),
      build: build,
      seed: () => const AuthSignedIn(_user),
      act: (c) => c.checkDevice(),
      expect: () => <AuthState>[],
      verify: (_) => verifyNever(() => auth.signOut()),
    );

    blocTest<AuthCubit, AuthState>(
      'P1-2: does nothing when the status call fails',
      setUp: () => when(
        () => devices.status(),
      ).thenAnswer((_) async => const Failure(_network)),
      build: build,
      seed: () => const AuthSignedIn(_user),
      act: (c) => c.checkDevice(),
      expect: () => <AuthState>[],
      verify: (_) => verifyNever(() => auth.signOut()),
    );

    blocTest<AuthCubit, AuthState>(
      'P1-2: does nothing when not signed in',
      build: build,
      seed: () => const AuthSignedOut(),
      act: (c) => c.checkDevice(),
      expect: () => <AuthState>[],
      verify: (_) => verifyNever(() => devices.status()),
    );
  });

  group('P1-2: ticker', () {
    test('P1-2: a tick after SignedIn runs the revocation check', () async {
      when(
        () => devices.status(),
      ).thenAnswer((_) async => const Success(DeviceStatus.revoked));
      final cubit = build();
      addTearDown(cubit.close);

      await cubit.start();
      ticks.add(null);
      await pumpEventQueue();

      verify(() => devices.status()).called(1);
      expect(
        cubit.state,
        const AuthSignedOut(reason: SignOutReason.deviceRemoved),
      );
    });

    test('P1-2: no tick is observed before SignedIn', () async {
      when(() => auth.currentUser).thenReturn(null);
      final cubit = build();
      addTearDown(cubit.close);

      await cubit.start();
      ticks.add(null);
      await pumpEventQueue();

      verifyNever(() => devices.status());
    });

    test('P1-2: after signOut a tick makes no call and no emit', () async {
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.start();
      await cubit.signOut();
      final states = <AuthState>[];
      final sub = cubit.stream.listen(states.add);
      addTearDown(sub.cancel);

      ticks.add(null);
      await pumpEventQueue();

      verifyNever(() => devices.status());
      expect(states, isEmpty);
      expect(ticks.hasListener, isFalse);
    });

    test('P1-2: after close a tick makes no call and no emit', () async {
      final cubit = build();
      await cubit.start();
      expect(ticks.hasListener, isTrue);

      await cubit.close();
      ticks.add(null);
      await pumpEventQueue();

      verifyNever(() => devices.status());
      expect(ticks.hasListener, isFalse);
    });
  });

  group('P1-2: signOut', () {
    blocTest<AuthCubit, AuthState>(
      'P1-2: emits SignedOut with the reason and clears the reporter user',
      build: build,
      seed: () => const AuthSignedIn(_user),
      act: (c) => c.signOut(SignOutReason.changesExhausted),
      expect: () => [
        const AuthSignedOut(reason: SignOutReason.changesExhausted),
      ],
      verify: (_) {
        verify(() => auth.signOut()).called(1);
        verify(() => reporter.clearUser()).called(1);
      },
    );

    blocTest<AuthCubit, AuthState>(
      'P1-2: emits SignedOut without a reason by default',
      build: build,
      seed: () => const AuthSignedIn(_user),
      act: (c) => c.signOut(),
      expect: () => [const AuthSignedOut()],
    );

    blocTest<AuthCubit, AuthState>(
      'P1-2: still emits SignedOut when the repository sign out fails',
      setUp: () => when(
        () => auth.signOut(),
      ).thenAnswer((_) async => const Failure(_network)),
      build: build,
      seed: () => const AuthSignedIn(_user),
      act: (c) => c.signOut(),
      expect: () => [const AuthSignedOut()],
    );
  });

  group('P1-2: checkDevice register outcomes', () {
    blocTest<AuthCubit, AuthState>(
      'P1-2: unknown then limit reached shows the DeviceGate',
      setUp: () {
        when(
          () => devices.status(),
        ).thenAnswer((_) async => const Success(DeviceStatus.unknown));
        when(
          () => devices.register(),
        ).thenAnswer((_) async => const Success(_limit));
      },
      build: build,
      seed: () => const AuthSignedIn(_user),
      act: (c) => c.checkDevice(),
      expect: () => [_gate],
    );

    blocTest<AuthCubit, AuthState>(
      'P1-2: unknown then register failure keeps the state',
      setUp: () {
        when(
          () => devices.status(),
        ).thenAnswer((_) async => const Success(DeviceStatus.unknown));
        when(
          () => devices.register(),
        ).thenAnswer((_) async => const Failure(_network));
      },
      build: build,
      seed: () => const AuthSignedIn(_user),
      act: (c) => c.checkDevice(),
      expect: () => <AuthState>[],
    );
  });

  group('P1-2: signOut invalidates in-flight work', () {
    test(
      'P1-2: stale unknown status after signOut makes no register',
      () async {
        final pending = Completer<Result<DeviceStatus>>();
        when(() => devices.status()).thenAnswer((_) => pending.future);
        final cubit = build();
        addTearDown(cubit.close);
        await cubit.start();
        final check = cubit.checkDevice();
        await pumpEventQueue();
        await cubit.signOut();
        final states = <AuthState>[];
        final sub = cubit.stream.listen(states.add);
        addTearDown(sub.cancel);

        pending.complete(const Success(DeviceStatus.unknown));
        await check;
        await pumpEventQueue();

        expect(states, isEmpty);
        expect(cubit.state, const AuthSignedOut());
        verify(() => devices.register()).called(1); // only from start()
      },
    );

    test('P1-2: stale revoked status after signOut stays plain', () async {
      final pending = Completer<Result<DeviceStatus>>();
      when(() => devices.status()).thenAnswer((_) => pending.future);
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.start();
      final check = cubit.checkDevice();
      await pumpEventQueue();
      await cubit.signOut();
      final states = <AuthState>[];
      final sub = cubit.stream.listen(states.add);
      addTearDown(sub.cancel);

      pending.complete(const Success(DeviceStatus.revoked));
      await check;
      await pumpEventQueue();

      expect(states, isEmpty);
      expect(cubit.state, const AuthSignedOut());
    });

    test('P1-2: signIn works after a stale check was overtaken', () async {
      final pending = Completer<Result<DeviceStatus>>();
      when(() => devices.status()).thenAnswer((_) => pending.future);
      when(
        () => auth.signIn(email: 'a@b.co', password: 'pw'),
      ).thenAnswer((_) async => const Success(_user));
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.start();
      final check = cubit.checkDevice();
      await pumpEventQueue();
      await cubit.signOut();

      await cubit.signIn('a@b.co', 'pw');

      verify(() => auth.signIn(email: 'a@b.co', password: 'pw')).called(1);
      expect(cubit.state, const AuthSignedIn(_user));
      pending.complete(const Success(DeviceStatus.active));
      await check;
    });

    for (final success in [true, false]) {
      test(
        'P1-2: stale remove ${success ? 'success' : 'failure'} after '
        'signOut makes no emit and no register',
        () async {
          when(
            () => devices.register(),
          ).thenAnswer((_) async => const Success(_limit));
          final pending = Completer<Result<int>>();
          when(() => devices.remove('d1')).thenAnswer((_) => pending.future);
          final cubit = build();
          addTearDown(cubit.close);
          await cubit.start();
          expect(cubit.state, _gate);
          final removal = cubit.removeDevice('d1');
          await pumpEventQueue();
          await cubit.signOut();
          final states = <AuthState>[];
          final sub = cubit.stream.listen(states.add);
          addTearDown(sub.cancel);

          pending.complete(
            success
                ? const Success<int>(0)
                : const Failure<int>(_deviceLimitError),
          );
          await removal;
          await pumpEventQueue();

          expect(states, isEmpty);
          expect(cubit.state, const AuthSignedOut());
          verify(() => devices.register()).called(1); // only from start()
        },
      );
    }

    test('P1-2: clearUser runs even if closed during auth.signOut', () async {
      final pending = Completer<Result<void>>();
      when(() => auth.signOut()).thenAnswer((_) => pending.future);
      final cubit = build();
      await cubit.start();

      final out = cubit.signOut();
      await pumpEventQueue();
      await cubit.close();
      pending.complete(const Success(null));
      await out;

      verify(() => reporter.clearUser()).called(1);
    });
  });

  group('P1-2: register without a user', () {
    blocTest<AuthCubit, AuthState>(
      'P1-2: signUp signedIn with no current user is not_authenticated',
      setUp: () {
        when(() => auth.currentUser).thenReturn(null);
        when(
          () => auth.signUp(
            email: 'a@b.co',
            password: 'pw',
            fullName: 'Sam Ali',
          ),
        ).thenAnswer((_) async => const Success(SignUpOutcome.signedIn));
      },
      build: build,
      act: (c) => c.signUp('a@b.co', 'pw', 'Sam Ali'),
      expect: () => [
        const AuthBusy(),
        isA<AuthSignedOut>().having(
          (s) => s.error?.code,
          'error code',
          ErrorCodes.notAuthenticated,
        ),
      ],
      verify: (_) => verifyNever(() => devices.register()),
    );
  });

  group('P1-2: state toString', () {
    test('P1-2: AuthSignedIn.toString does not contain the email', () {
      expect(const AuthSignedIn(_user).toString(), isNot(contains('a@b.co')));
    });

    test('P1-2: AuthConfirmationSent.toString does not contain the email', () {
      expect(
        const AuthConfirmationSent('a@b.co').toString(),
        isNot(contains('a@b.co')),
      );
    });
  });
}
