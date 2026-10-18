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
  late StreamController<AppUser?> users;
  late StreamController<void> recovery;

  setUp(() {
    auth = MockAuthRepository();
    devices = MockDeviceRepository();
    reporter = MockErrorReporter();
    ticks = StreamController<void>.broadcast();
    addTearDown(ticks.close);
    users = StreamController<AppUser?>.broadcast();
    addTearDown(users.close);
    when(() => auth.userChanges).thenAnswer((_) => users.stream);
    recovery = StreamController<void>.broadcast();
    addTearDown(recovery.close);
    when(() => auth.passwordRecovery).thenAnswer((_) => recovery.stream);

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

  group('AUTH-06: password recovery', () {
    test(
      'AUTH-06: replayed expiry is handled before startup registration',
      () async {
        when(() => auth.passwordRecovery).thenAnswer(
          (_) => Stream<void>.error(const AppError(ErrorCodes.linkExpired)),
        );
        final cubit = build();
        addTearDown(cubit.close);
        await cubit.start();
        expect(
          cubit.state,
          const AuthSignedOut(error: AppError(ErrorCodes.linkExpired)),
        );
        verifyNever(() => devices.register());
      },
    );
    for (final code in [ErrorCodes.linkExpired, ErrorCodes.network]) {
      test(
        'AUTH-06: recovery stream handles $code without uncaught errors',
        () async {
          final cubit = AuthCubit(
            auth,
            devices,
            reporter,
            ticker: (_) => ticks.stream,
            initialUri: Uri.parse('https://app.test/?flow=recovery'),
          );
          addTearDown(cubit.close);
          when(() => auth.currentUser).thenReturn(null);
          await cubit.start();
          recovery.add(null);
          await pumpEventQueue();
          recovery.addError(AppError(code));
          await pumpEventQueue();
          expect(
            cubit.state,
            code == ErrorCodes.linkExpired
                ? const AuthSignedOut(error: AppError(ErrorCodes.linkExpired))
                : const AuthRecovery(error: AppError(ErrorCodes.network)),
          );
          verifyNever(() => devices.register());
        },
      );
    }
    blocTest<AuthCubit, AuthState>(
      'AUTH-06: acknowledging a reset link returns to sign in',
      build: build,
      seed: () => const AuthResetLinkSent('a@b.co'),
      act: (c) => c.acknowledgeConfirmation(),
      expect: () => [const AuthSignedOut()],
    );

    blocTest<AuthCubit, AuthState>(
      'AUTH-06: a password save outside recovery does nothing',
      build: build,
      seed: () => const AuthSignedOut(),
      act: (c) => c.setNewPassword('Password1'),
      expect: () => <AuthState>[],
      verify: (_) => verifyNever(() => auth.updatePassword(any())),
    );

    test('AUTH-06: late recovery invalidates pending registration', () async {
      final pending = Completer<Result<DeviceRegistration>>();
      when(() => devices.register()).thenAnswer((_) => pending.future);
      final cubit = build();
      addTearDown(cubit.close);
      final starting = cubit.start();
      recovery.add(null);
      await pumpEventQueue();
      pending.complete(const Success<DeviceRegistration>(_allowed));
      await starting;
      expect(cubit.state, const AuthRecovery());
      verifyNever(() => reporter.setUser(any()));
    });

    test('AUTH-06: closed recovery ignores a pending password save', () async {
      final pending = Completer<Result<void>>();
      when(() => auth.currentUser).thenReturn(null);
      when(
        () => auth.updatePassword('Password1'),
      ).thenAnswer((_) => pending.future);
      final cubit = build();
      await cubit.start();
      recovery.add(null);
      await pumpEventQueue();
      final saving = cubit.setNewPassword('Password1');
      await cubit.close();
      pending.complete(const Success<void>(null));
      await saving;
      verifyNever(() => devices.register());
      expect(cubit.state, const AuthRecovery(saving: true));
    });
    test(
      'AUTH-06: late recovery replaces SignedOut without registering',
      () async {
        when(() => auth.currentUser).thenReturn(null);
        final cubit = build();
        addTearDown(cubit.close);
        await cubit.start();
        expect(cubit.state, const AuthSignedOut());
        recovery.add(null);
        await pumpEventQueue();
        expect(cubit.state, const AuthRecovery());
        await cubit.start();
        expect(cubit.state, const AuthRecovery());
        verifyNever(() => devices.register());
      },
    );

    test(
      'AUTH-06: replayed recovery precedes startup registration',
      () async {
        when(
          () => auth.passwordRecovery,
        ).thenAnswer((_) => Stream<void>.value(null));
        final cubit = AuthCubit(
          auth,
          devices,
          reporter,
          ticker: (_) => ticks.stream,
          initialUri: Uri.parse('https://app.test/?flow=recovery&code=test'),
        );
        addTearDown(cubit.close);
        await cubit.start();
        expect(cubit.state, const AuthRecovery());
        verifyNever(() => devices.register());
      },
    );

    test(
      'AUTH-06: stale marker without code or event restores signed in',
      () async {
        final cubit = AuthCubit(
          auth,
          devices,
          reporter,
          ticker: (_) => ticks.stream,
          initialUri: Uri.parse('https://app.test/?flow=recovery'),
        );
        addTearDown(cubit.close);
        await cubit.start();
        expect(cubit.state, const AuthSignedIn(_user));
        verify(() => devices.register()).called(1);
      },
    );

    for (final url in [
      'https://app.test/?flow=recovery&error_code=otp_expired',
      'https://app.test/#error=access_denied',
    ]) {
      test('AUTH-06: expired startup URL produces link_expired $url', () async {
        final cubit = AuthCubit(
          auth,
          devices,
          reporter,
          ticker: (_) => ticks.stream,
          initialUri: Uri.parse(url),
        );
        addTearDown(cubit.close);
        await cubit.start();
        recovery.add(null);
        await pumpEventQueue();
        expect(
          cubit.state,
          const AuthSignedOut(
            error: AppError(ErrorCodes.linkExpired),
          ),
        );
        verifyNever(() => devices.register());
      });
    }

    for (final email in ['known@example.com', 'unknown@example.com']) {
      blocTest<AuthCubit, AuthState>(
        'AUTH-06: reset request succeeds identically for $email',
        setUp: () => when(
          () => auth.requestPasswordReset(email),
        ).thenAnswer((_) async => const Success<void>(null)),
        build: build,
        seed: () => const AuthSignedOut(),
        act: (c) => c.requestPasswordReset(email),
        expect: () => [const AuthBusy(), AuthResetLinkSent(email)],
        verify: (_) => verifyNever(() => devices.register()),
      );
    }

    for (final code in [ErrorCodes.rateLimited, ErrorCodes.network]) {
      blocTest<AuthCubit, AuthState>(
        'AUTH-06: reset request exposes $code',
        setUp: () => when(
          () => auth.requestPasswordReset('a@b.co'),
        ).thenAnswer((_) async => Failure<void>(AppError(code))),
        build: build,
        seed: () => const AuthSignedOut(),
        act: (c) => c.requestPasswordReset('a@b.co'),
        expect: () => [const AuthBusy(), AuthSignedOut(error: AppError(code))],
      );
    }

    blocTest<AuthCubit, AuthState>(
      'AUTH-06: successful password save resumes device registration',
      setUp: () => when(
        () => auth.updatePassword('Password1'),
      ).thenAnswer((_) async => const Success<void>(null)),
      build: build,
      seed: () => const AuthRecovery(),
      act: (c) => c.setNewPassword('Password1'),
      expect: () => [
        const AuthRecovery(saving: true),
        const AuthSignedIn(_user),
      ],
      verify: (_) => verify(() => devices.register()).called(1),
    );

    for (final code in [
      ErrorCodes.weakPassword,
      ErrorCodes.rateLimited,
      ErrorCodes.network,
    ]) {
      blocTest<AuthCubit, AuthState>(
        'AUTH-06: failed password save preserves recovery with $code',
        setUp: () => when(
          () => auth.updatePassword('Password1'),
        ).thenAnswer((_) async => Failure<void>(AppError(code))),
        build: build,
        seed: () => const AuthRecovery(),
        act: (c) => c.setNewPassword('Password1'),
        expect: () => [
          const AuthRecovery(saving: true),
          AuthRecovery(error: AppError(code)),
        ],
        verify: (_) => verifyNever(() => devices.register()),
      );
    }

    blocTest<AuthCubit, AuthState>(
      'AUTH-06: lost recovery session asks for a new link',
      setUp: () => when(() => auth.updatePassword('Password1')).thenAnswer(
        (_) async => const Failure<void>(
          AppError(ErrorCodes.notAuthenticated),
        ),
      ),
      build: build,
      seed: () => const AuthRecovery(),
      act: (c) => c.setNewPassword('Password1'),
      expect: () => [
        const AuthRecovery(saving: true),
        const AuthSignedOut(error: AppError(ErrorCodes.linkExpired)),
      ],
    );

    test('AUTH-06: pending save cannot register or save twice', () async {
      final pending = Completer<Result<void>>();
      when(
        () => auth.updatePassword('Password1'),
      ).thenAnswer((_) => pending.future);
      when(() => auth.currentUser).thenReturn(null);
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.start();
      recovery.add(null);
      await pumpEventQueue();
      final saving = cubit.setNewPassword('Password1');
      await cubit.setNewPassword('Password1');
      verifyNever(() => devices.register());
      verify(() => auth.updatePassword('Password1')).called(1);
      when(() => auth.currentUser).thenReturn(_user);
      pending.complete(const Success<void>(null));
      await saving;
      expect(cubit.state, const AuthSignedIn(_user));
    });

    test(
      'AUTH-06: close cancels recovery and ignores late reset completion',
      () async {
        final pending = Completer<Result<void>>();
        when(() => auth.currentUser).thenReturn(null);
        when(
          () => auth.requestPasswordReset('a@b.co'),
        ).thenAnswer((_) => pending.future);
        final cubit = build();
        await cubit.start();
        expect(recovery.hasListener, isTrue);
        final sending = cubit.requestPasswordReset('a@b.co');
        await cubit.close();
        pending.complete(const Success<void>(null));
        await sending;
        expect(recovery.hasListener, isFalse);
        expect(cubit.state, const AuthBusy());
      },
    );

    test('AUTH-06: reset confirmation keeps email out of logs', () {
      expect(
        const AuthResetLinkSent('a@b.co').toString(),
        isNot(contains('a@b.co')),
      );
    });
  });

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
      act: (c) => c.signOut(SignOutReason.deviceRemoved),
      expect: () => [
        const AuthSignedOut(reason: SignOutReason.deviceRemoved),
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

  group('P1-2: operations rejected while signing out', () {
    test(
      'P1-2: checkDevice during signOut makes no register or emit',
      () async {
        final pendingOut = Completer<Result<void>>();
        when(() => auth.signOut()).thenAnswer((_) => pendingOut.future);
        when(
          () => devices.status(),
        ).thenAnswer((_) async => const Success(DeviceStatus.unknown));
        final cubit = build();
        addTearDown(cubit.close);
        await cubit.start();
        final states = <AuthState>[];
        final sub = cubit.stream.listen(states.add);
        addTearDown(sub.cancel);

        final out = cubit.signOut();
        await pumpEventQueue();
        await cubit.checkDevice();
        pendingOut.complete(const Success(null));
        await out;
        await pumpEventQueue();

        expect(cubit.state, const AuthSignedOut());
        expect(states, [const AuthSignedOut()]);
        verify(() => devices.register()).called(1); // only from start()
        verify(() => reporter.setUser('u1')).called(1); // only from start()
        verify(() => reporter.clearUser()).called(1);
      },
    );

    test('P1-2: removeDevice during signOut never calls remove', () async {
      when(
        () => devices.register(),
      ).thenAnswer((_) async => const Success(_limit));
      final pendingOut = Completer<Result<void>>();
      when(() => auth.signOut()).thenAnswer((_) => pendingOut.future);
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.start();
      expect(cubit.state, _gate);
      final states = <AuthState>[];
      final sub = cubit.stream.listen(states.add);
      addTearDown(sub.cancel);

      final out = cubit.signOut();
      await pumpEventQueue();
      await cubit.removeDevice('d1');
      pendingOut.complete(const Success(null));
      await out;
      await pumpEventQueue();

      verifyNever(() => devices.remove(any()));
      expect(cubit.state, const AuthSignedOut());
      expect(states, [const AuthSignedOut()]);
    });

    test(
      'P1-2: signIn reaches the repository after signOut completes',
      () async {
        when(
          () => auth.signIn(email: 'a@b.co', password: 'pw'),
        ).thenAnswer((_) async => const Success(_user));
        final cubit = build();
        addTearDown(cubit.close);
        await cubit.start();
        await cubit.signOut();

        await cubit.signIn('a@b.co', 'pw');

        verify(() => auth.signIn(email: 'a@b.co', password: 'pw')).called(1);
        expect(cubit.state, const AuthSignedIn(_user));
      },
    );

    test('P1-2: a stale finally does not release a newer guard', () async {
      final pendingStatus = Completer<Result<DeviceStatus>>();
      when(() => devices.status()).thenAnswer((_) => pendingStatus.future);
      final pendingSignIn = Completer<Result<AppUser>>();
      when(
        () => auth.signIn(email: 'a@b.co', password: 'pw'),
      ).thenAnswer((_) => pendingSignIn.future);
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.start();
      final stale = cubit.checkDevice();
      await pumpEventQueue();
      await cubit.signOut();
      final newer = cubit.signIn('a@b.co', 'pw');
      await pumpEventQueue();

      pendingStatus.complete(const Success(DeviceStatus.active));
      await stale;
      final third = cubit.signIn('a@b.co', 'pw');
      await pumpEventQueue();

      verify(() => auth.signIn(email: 'a@b.co', password: 'pw')).called(1);
      pendingSignIn.complete(const Success(_user));
      await Future.wait([newer, third]);
    });
  });

  group('P1-2: clearError', () {
    blocTest<AuthCubit, AuthState>(
      'P1-2: clears the error of SignedOut',
      build: build,
      seed: () => const AuthSignedOut(error: _network),
      act: (c) => c.clearError(),
      expect: () => [const AuthSignedOut()],
    );

    blocTest<AuthCubit, AuthState>(
      'P1-2: keeps the reason when clearing the error',
      build: build,
      seed: () => const AuthSignedOut(
        reason: SignOutReason.deviceRemoved,
        error: _network,
      ),
      act: (c) => c.clearError(),
      expect: () => [
        const AuthSignedOut(reason: SignOutReason.deviceRemoved),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'P1-2: does nothing on SignedOut with only a reason',
      build: build,
      seed: () => const AuthSignedOut(reason: SignOutReason.deviceRemoved),
      act: (c) => c.clearError(),
      expect: () => <AuthState>[],
    );

    blocTest<AuthCubit, AuthState>(
      'P1-2: does nothing on a plain SignedOut',
      build: build,
      seed: () => const AuthSignedOut(),
      act: (c) => c.clearError(),
      expect: () => <AuthState>[],
    );

    blocTest<AuthCubit, AuthState>(
      'P1-2: does nothing on SignedIn',
      build: build,
      seed: () => const AuthSignedIn(_user),
      act: (c) => c.clearError(),
      expect: () => <AuthState>[],
    );

    blocTest<AuthCubit, AuthState>(
      'P1-2: does nothing on Busy',
      build: build,
      seed: () => const AuthBusy(),
      act: (c) => c.clearError(),
      expect: () => <AuthState>[],
    );

    blocTest<AuthCubit, AuthState>(
      'P1-2: does nothing on a DeviceGate with an error',
      build: build,
      seed: () => const AuthDeviceGate(
        devices: [_device],
        changesLeft: 1,
        error: _forbidden,
      ),
      act: (c) => c.clearError(),
      expect: () => <AuthState>[],
    );
  });

  group('P1-2: acknowledgeConfirmation', () {
    blocTest<AuthCubit, AuthState>(
      'P1-2: moves ConfirmationSent to SignedOut',
      build: build,
      seed: () => const AuthConfirmationSent('a@b.co'),
      act: (c) => c.acknowledgeConfirmation(),
      expect: () => [const AuthSignedOut()],
    );

    final others = <String, AuthState>{
      'SignedOut with an error': const AuthSignedOut(error: _network),
      'SignedIn': const AuthSignedIn(_user),
      'Busy': const AuthBusy(),
      'DeviceGate': _gate,
      'Unknown': const AuthUnknown(),
    };
    for (final entry in others.entries) {
      blocTest<AuthCubit, AuthState>(
        'P1-2: does nothing on ${entry.key}',
        build: build,
        seed: () => entry.value,
        act: (c) => c.acknowledgeConfirmation(),
        expect: () => <AuthState>[],
      );
    }
  });

  group('P1-2: session loss', () {
    test('P1-2: a null user while SignedIn signs out', () async {
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.start();
      expect(cubit.state, const AuthSignedIn(_user));

      users.add(null);
      await pumpEventQueue();

      expect(cubit.state, const AuthSignedOut());
      expect(ticks.hasListener, isFalse);
    });

    test('P1-2: after session loss a tick makes no further call', () async {
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.start();
      users.add(null);
      await pumpEventQueue();

      ticks.add(null);
      await pumpEventQueue();

      verifyNever(() => devices.status());
      verify(() => devices.register()).called(1);
    });

    test('P1-2: a null user while DeviceGate signs out', () async {
      when(
        () => devices.register(),
      ).thenAnswer((_) async => const Success(_limit));
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.start();
      expect(cubit.state, _gate);

      users.add(null);
      await pumpEventQueue();

      expect(cubit.state, const AuthSignedOut());
    });

    test('P1-2: a null user while ConfirmationSent signs out', () async {
      when(
        () => auth.signUp(
          email: 'a@b.co',
          password: 'pw',
          fullName: 'Sam Ali',
        ),
      ).thenAnswer((_) async => const Success(SignUpOutcome.confirmationSent));
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.start();
      await cubit.signUp('a@b.co', 'pw', 'Sam Ali');
      expect(cubit.state, const AuthConfirmationSent('a@b.co'));

      users.add(null);
      await pumpEventQueue();

      expect(cubit.state, const AuthSignedOut());
    });

    test('P1-2: two back-to-back null users sign out once', () async {
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.start();
      final states = <AuthState>[];
      final sub = cubit.stream.listen(states.add);
      addTearDown(sub.cancel);

      users
        ..add(null)
        ..add(null);
      await pumpEventQueue();

      expect(states, [const AuthSignedOut()]);
      verify(() => reporter.clearUser()).called(1);
    });

    test('P1-2: a second real loss after re-sign-in signs out again', () async {
      when(
        () => auth.signIn(email: 'a@b.co', password: 'pw'),
      ).thenAnswer((_) async => const Success(_user));
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.start();
      final states = <AuthState>[];
      final sub = cubit.stream.listen(states.add);
      addTearDown(sub.cancel);

      users.add(null);
      await pumpEventQueue();
      await cubit.signIn('a@b.co', 'pw');
      await pumpEventQueue();
      expect(cubit.state, const AuthSignedIn(_user));
      users.add(null);
      await pumpEventQueue();

      expect(states, [
        const AuthSignedOut(),
        const AuthBusy(),
        const AuthSignedIn(_user),
        const AuthSignedOut(),
      ]);
      verify(() => reporter.clearUser()).called(2);
    });

    test('P1-2: clearUser throwing still signs out and reports', () async {
      when(
        () => reporter.captureError(
          any<Object>(),
          any(),
          hint: any(named: 'hint'),
        ),
      ).thenAnswer((_) async {});
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.start();
      when(() => reporter.clearUser()).thenThrow(StateError('boom'));

      users.add(null);
      await pumpEventQueue();

      expect(cubit.state, const AuthSignedOut());
      verify(
        () => reporter.captureError(
          any<Object>(),
          any(),
          hint: any(named: 'hint'),
        ),
      ).called(1);
    });

    test('P1-2: operations are rejected while a session loss runs', () async {
      final pending = Completer<void>();
      when(() => reporter.clearUser()).thenAnswer((_) => pending.future);
      when(
        () => devices.status(),
      ).thenAnswer((_) async => const Success(DeviceStatus.active));
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.start();

      users.add(null);
      await pumpEventQueue();
      await cubit.checkDevice();
      pending.complete();
      await pumpEventQueue();

      verifyNever(() => devices.status());
      expect(cubit.state, const AuthSignedOut());
    });

    test('P1-2: a null user during sign-in does not sign out', () async {
      final pending = Completer<Result<AppUser>>();
      when(
        () => auth.signIn(email: 'a@b.co', password: 'pw'),
      ).thenAnswer((_) => pending.future);
      final cubit = build();
      addTearDown(cubit.close);
      final states = <AuthState>[];
      final sub = cubit.stream.listen(states.add);
      addTearDown(sub.cancel);
      await cubit.start();
      await cubit.signOut();
      await pumpEventQueue();
      states.clear();

      final signingIn = cubit.signIn('a@b.co', 'pw');
      await pumpEventQueue();
      expect(cubit.state, const AuthBusy());
      users.add(null);
      await pumpEventQueue();
      pending.complete(const Success(_user));
      await signingIn;
      await pumpEventQueue();

      expect(cubit.state, const AuthSignedIn(_user));
      expect(states, [const AuthBusy(), const AuthSignedIn(_user)]);
    });

    test('P1-2: a non-null user event changes nothing', () async {
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.start();
      final states = <AuthState>[];
      final sub = cubit.stream.listen(states.add);
      addTearDown(sub.cancel);

      users.add(_user);
      await pumpEventQueue();

      expect(states, isEmpty);
    });

    test('P1-2: a null user while SignedOut emits nothing', () async {
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.start();
      await cubit.signOut();
      final states = <AuthState>[];
      final sub = cubit.stream.listen(states.add);
      addTearDown(sub.cancel);

      users.add(null);
      await pumpEventQueue();

      expect(states, isEmpty);
    });

    test('P1-2: close cancels the user subscription', () async {
      final cubit = build();
      await cubit.start();
      expect(users.hasListener, isTrue);

      await cubit.close();

      expect(users.hasListener, isFalse);
    });

    blocTest<AuthCubit, AuthState>(
      'P1-2: checkDevice not_authenticated signs out without a reason',
      setUp: () => when(() => devices.status()).thenAnswer(
        (_) async => const Failure(AppError(ErrorCodes.notAuthenticated)),
      ),
      build: build,
      seed: () => const AuthSignedIn(_user),
      act: (c) => c.checkDevice(),
      expect: () => [const AuthSignedOut()],
    );

    blocTest<AuthCubit, AuthState>(
      'P1-2: checkDevice with another failure keeps the state',
      setUp: () => when(
        () => devices.status(),
      ).thenAnswer((_) async => const Failure(_forbidden)),
      build: build,
      seed: () => const AuthSignedIn(_user),
      act: (c) => c.checkDevice(),
      expect: () => <AuthState>[],
    );
  });

  group('P1-2: overlapping signOut', () {
    test(
      'P1-2: two concurrent signOut calls hit the repository once',
      () async {
        final pending = Completer<Result<void>>();
        when(() => auth.signOut()).thenAnswer((_) => pending.future);
        final cubit = build();
        addTearDown(cubit.close);
        await cubit.start();

        final first = cubit.signOut(SignOutReason.deviceRemoved);
        final second = cubit.signOut();
        pending.complete(const Success(null));
        await Future.wait([first, second]);

        verify(() => auth.signOut()).called(1);
        expect(
          cubit.state,
          const AuthSignedOut(reason: SignOutReason.deviceRemoved),
        );
      },
    );
  });
}
