import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/auth/domain/entities/device.dart';
import 'package:sat_east_client/features/auth/domain/entities/my_devices.dart';
import 'package:sat_east_client/features/auth/domain/entities/my_enrollment.dart';
import 'package:sat_east_client/features/auth/domain/entities/my_profile.dart';
import 'package:sat_east_client/features/auth/domain/repositories/auth_repository.dart';
import 'package:sat_east_client/features/auth/domain/repositories/device_repository.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/account_cubit.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/account_state.dart';

class _Auth extends Mock implements AuthRepository {}

class _Devices extends Mock implements DeviceRepository {}

const _profile = MyProfile(fullName: 'Student Name', email: 's@example.com');
const _current = Device(id: 'current', label: 'Laptop', isCurrent: true);
const _other = Device(id: 'other', label: 'Phone');
const _network = AppError(ErrorCodes.network);
final _loaded = AccountLoaded(_profile, const [_current, _other], 2);
final _enrollment = MyEnrollment(
  courseTitle: 'SAT Math',
  targetTestDate: DateTime(2027, 3, 15),
  expiresAt: DateTime.utc(2027, 3, 30),
  isExpired: false,
);

void main() {
  late _Auth auth;
  late _Devices devices;
  setUp(() {
    auth = _Auth();
    devices = _Devices();
    when(auth.getMyProfile).thenAnswer((_) async => const Success(_profile));
    when(auth.listMyEnrollments).thenAnswer(
      (_) async => const Success<List<MyEnrollment>>([]),
    );
    when(devices.listMine).thenAnswer(
      (_) async =>
          Success(MyDevices(devices: const [_current, _other], changesLeft: 2)),
    );
    when(
      () => auth.updatePassword(any()),
    ).thenAnswer((_) async => const Success<void>(null));
    when(
      () => devices.remove('other'),
    ).thenAnswer((_) async => const Success(1));
  });
  AccountCubit build() => AccountCubit(auth, devices);

  blocTest<AccountCubit, AccountState>(
    'AUTH-02: load includes current enrollments',
    setUp: () => when(auth.listMyEnrollments).thenAnswer(
      (_) async => Success([_enrollment]),
    ),
    build: build,
    act: (c) => c.load(),
    expect: () => [
      const AccountLoading(),
      AccountLoaded(
        _profile,
        const [_current, _other],
        2,
        enrollments: [_enrollment],
      ),
    ],
    verify: (_) => verify(auth.listMyEnrollments).called(1),
  );

  blocTest<AccountCubit, AccountState>(
    'AUTH-02: load without enrollments still loads the account',
    build: build,
    act: (c) => c.load(),
    expect: () => [const AccountLoading(), _loaded],
    verify: (_) => verify(auth.listMyEnrollments).called(1),
  );

  for (final code in [
    ErrorCodes.network,
    ErrorCodes.notAuthenticated,
    ErrorCodes.forbidden,
    ErrorCodes.internal,
  ]) {
    blocTest<AccountCubit, AccountState>(
      'AUTH-02: enrollment load $code reports failure',
      setUp: () => when(auth.listMyEnrollments).thenAnswer(
        (_) async => Failure<List<MyEnrollment>>(AppError(code)),
      ),
      build: build,
      act: (c) => c.load(),
      expect: () => [const AccountLoading(), AccountError(AppError(code))],
    );
  }

  for (final fails in [false, true]) {
    blocTest<AccountCubit, AccountState>(
      'AUTH-02: password update failure=$fails preserves enrollments',
      setUp: () {
        when(() => auth.updatePassword('Password1')).thenAnswer(
          (_) async =>
              fails ? const Failure<void>(_network) : const Success<void>(null),
        );
      },
      build: build,
      seed: () => AccountLoaded(
        _profile,
        const [_current, _other],
        2,
        enrollments: [_enrollment],
      ),
      act: (c) => c.changePassword('Password1'),
      expect: () => [
        AccountLoaded(
          _profile,
          const [_current, _other],
          2,
          enrollments: [_enrollment],
          busy: true,
        ),
        AccountLoaded(
          _profile,
          const [_current, _other],
          2,
          enrollments: [_enrollment],
          passwordSaved: !fails,
          error: fails ? _network : null,
        ),
      ],
      verify: (_) => verifyNever(auth.listMyEnrollments),
    );

    blocTest<AccountCubit, AccountState>(
      'AUTH-02: device removal failure=$fails preserves enrollments',
      setUp: () {
        when(() => devices.remove('other')).thenAnswer(
          (_) async => fails ? const Failure<int>(_network) : const Success(1),
        );
        when(devices.listMine).thenAnswer(
          (_) async =>
              Success(MyDevices(devices: const [_current], changesLeft: 1)),
        );
      },
      build: build,
      seed: () => AccountLoaded(
        _profile,
        const [_current, _other],
        2,
        enrollments: [_enrollment],
      ),
      act: (c) => c.removeDevice('other'),
      expect: () => [
        AccountLoaded(
          _profile,
          const [_current, _other],
          2,
          enrollments: [_enrollment],
          busy: true,
        ),
        AccountLoaded(
          _profile,
          fails ? const [_current, _other] : const [_current],
          fails ? 2 : 1,
          enrollments: [_enrollment],
          error: fails ? _network : null,
        ),
      ],
      verify: (_) => verifyNever(auth.listMyEnrollments),
    );
  }

  test('AUTH-02: close suppresses late enrollment results', () async {
    final pending = Completer<Result<List<MyEnrollment>>>();
    final requested = Completer<void>();
    when(auth.listMyEnrollments).thenAnswer((_) {
      requested.complete();
      return pending.future;
    });
    final cubit = build();
    final loading = cubit.load();
    await requested.future;
    await cubit.close();
    pending.complete(Success([_enrollment]));

    await loading;

    expect(cubit.state, const AccountLoading());
  });

  test('AUTH-02: loaded enrollments are immutable snapshots', () {
    final source = [_enrollment];
    final loaded = AccountLoaded(_profile, const [], 2, enrollments: source);
    source.clear();

    expect(loaded.enrollments, [_enrollment]);
    expect(loaded.enrollments.clear, throwsUnsupportedError);
  });

  test('AUTH-02: enrollment changes participate in state equality', () {
    final first = AccountLoaded(_profile, const [], 2);
    final second = AccountLoaded(
      _profile,
      const [],
      2,
      enrollments: [_enrollment],
    );

    expect(first, isNot(second));
    expect(
      second,
      AccountLoaded(_profile, const [], 2, enrollments: [_enrollment]),
    );
  });

  blocTest<AccountCubit, AccountState>(
    'S-34: load fetches profile and devices',
    build: build,
    act: (c) => c.load(),
    expect: () => [const AccountLoading(), _loaded],
  );
  blocTest<AccountCubit, AccountState>(
    'S-34: load reports profile failure',
    setUp: () => when(
      auth.getMyProfile,
    ).thenAnswer((_) async => const Failure<MyProfile>(_network)),
    build: build,
    act: (c) => c.load(),
    expect: () => [const AccountLoading(), const AccountError(_network)],
    verify: (_) => verifyNever(devices.listMine),
  );
  blocTest<AccountCubit, AccountState>(
    'AUTH-04: load reports device-list failure',
    setUp: () => when(
      devices.listMine,
    ).thenAnswer((_) async => const Failure<MyDevices>(_network)),
    build: build,
    act: (c) => c.load(),
    expect: () => [const AccountLoading(), const AccountError(_network)],
  );
  blocTest<AccountCubit, AccountState>(
    'AUTH-04: load accepts an empty device list',
    setUp: () =>
        when(
          devices.listMine,
        ).thenAnswer(
          (_) async => Success(MyDevices(devices: const [], changesLeft: 2)),
        ),
    build: build,
    act: (c) => c.load(),
    expect: () => [
      const AccountLoading(),
      AccountLoaded(_profile, const [], 2),
    ],
  );
  blocTest<AccountCubit, AccountState>(
    'S-34: password success preserves account and confirms save',
    build: build,
    seed: () => _loaded,
    act: (c) => c.changePassword('Password1'),
    expect: () => [
      AccountLoaded(_profile, const [_current, _other], 2, busy: true),
      AccountLoaded(_profile, const [_current, _other], 2, passwordSaved: true),
    ],
  );
  for (final code in [
    ErrorCodes.weakPassword,
    ErrorCodes.rateLimited,
    ErrorCodes.network,
    ErrorCodes.notAuthenticated,
  ]) {
    blocTest<AccountCubit, AccountState>(
      'S-34: password failure $code preserves account',
      setUp: () => when(
        () => auth.updatePassword('Password1'),
      ).thenAnswer((_) async => Failure<void>(AppError(code))),
      build: build,
      seed: () => _loaded,
      act: (c) => c.changePassword('Password1'),
      expect: () => [
        AccountLoaded(_profile, const [_current, _other], 2, busy: true),
        AccountLoaded(
          _profile,
          const [_current, _other],
          2,
          error: AppError(code),
        ),
      ],
    );
  }
  blocTest<AccountCubit, AccountState>(
    'AUTH-04: removal refreshes devices and server allowance',
    setUp: () => when(devices.listMine).thenAnswer(
      (_) async =>
          Success(MyDevices(devices: const [_current], changesLeft: 1)),
    ),
    build: build,
    seed: () => _loaded,
    act: (c) => c.removeDevice('other'),
    expect: () => [
      AccountLoaded(_profile, const [_current, _other], 2, busy: true),
      AccountLoaded(_profile, const [_current], 1),
    ],
    verify: (_) {
      verify(() => devices.remove('other')).called(1);
      verify(devices.listMine).called(1);
    },
  );
  for (final code in [ErrorCodes.deviceLimit, ErrorCodes.network]) {
    blocTest<AccountCubit, AccountState>(
      'AUTH-04: removal failure $code preserves devices',
      setUp: () => when(
        () => devices.remove('other'),
      ).thenAnswer((_) async => Failure<int>(AppError(code))),
      build: build,
      seed: () => _loaded,
      act: (c) => c.removeDevice('other'),
      expect: () => [
        AccountLoaded(_profile, const [_current, _other], 2, busy: true),
        AccountLoaded(
          _profile,
          const [_current, _other],
          code == ErrorCodes.deviceLimit ? 0 : 2,
          error: AppError(code),
        ),
      ],
    );
  }
  blocTest<AccountCubit, AccountState>(
    'AUTH-04: refresh failure retains authoritative removal result',
    setUp: () => when(
      devices.listMine,
    ).thenAnswer((_) async => const Failure<MyDevices>(_network)),
    build: build,
    seed: () => _loaded,
    act: (c) => c.removeDevice('other'),
    expect: () => [
      AccountLoaded(_profile, const [_current, _other], 2, busy: true),
      AccountLoaded(_profile, const [_current], 1, error: _network),
    ],
  );
  for (final (id, allowance) in [
    ('current', 2),
    ('missing', 2),
    ('other', 0),
  ]) {
    blocTest<AccountCubit, AccountState>(
      'AUTH-04: prevents removal of $id with allowance $allowance',
      build: build,
      seed: () => AccountLoaded(_profile, const [_current, _other], allowance),
      act: (c) => c.removeDevice(id),
      expect: () => <AccountState>[],
      verify: (_) => verifyNever(() => devices.remove(any())),
    );
  }

  test('S-34: overlapping operations are ignored while saving', () async {
    final pending = Completer<Result<void>>();
    when(
      () => auth.updatePassword('Password1'),
    ).thenAnswer((_) => pending.future);
    final cubit = build();
    addTearDown(cubit.close);
    await cubit.load();
    final saving = cubit.changePassword('Password1');
    await cubit.changePassword('Password1');
    await cubit.removeDevice('other');
    await cubit.load();
    verify(() => auth.updatePassword('Password1')).called(1);
    verifyNever(() => devices.remove(any()));
    pending.complete(const Success<void>(null));
    await saving;
  });

  test('S-34: close suppresses a late profile load', () async {
    final pending = Completer<Result<MyProfile>>();
    when(auth.getMyProfile).thenAnswer((_) => pending.future);
    final cubit = build();
    final loading = cubit.load();
    await cubit.close();
    pending.complete(const Success(_profile));
    await loading;
    expect(cubit.state, const AccountLoading());
    verifyNever(devices.listMine);
  });
  test('S-34: close suppresses a late password save', () async {
    final pending = Completer<Result<void>>();
    when(
      () => auth.updatePassword('Password1'),
    ).thenAnswer((_) => pending.future);
    final cubit = build();
    await cubit.load();
    final saving = cubit.changePassword('Password1');
    await cubit.close();
    pending.complete(const Success<void>(null));
    await saving;
    expect((cubit.state as AccountLoaded).passwordSaved, isFalse);
  });
  test('AUTH-04: close suppresses a late removal', () async {
    final pending = Completer<Result<int>>();
    when(() => devices.remove('other')).thenAnswer((_) => pending.future);
    final cubit = build();
    await cubit.load();
    final removing = cubit.removeDevice('other');
    await cubit.close();
    pending.complete(const Success(1));
    await removing;
    expect((cubit.state as AccountLoaded).devices, [_current, _other]);
    verify(devices.listMine).called(1);
  });
}
