import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:sat_east_client/features/auth/domain/entities/app_user.dart';
import 'package:sat_east_client/features/auth/domain/entities/sign_up_outcome.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fakes.dart';

User _user({
  String id = 'u1',
  String? email = 'a@b.co',
  List<UserIdentity>? identities,
}) => User(
  id: id,
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-10-01T00:00:00Z',
  email: email,
  identities: identities,
);

Session _session(User user) =>
    Session(accessToken: 'token', tokenType: 'bearer', user: user);

void main() {
  late MockGoTrueClient auth;
  late AuthRemoteDataSource source;

  setUp(() {
    auth = MockGoTrueClient();
    source = AuthRemoteDataSource(auth, client: MockSupabaseClient());
  });

  group('P1-2: signIn', () {
    test('P1-2: returns the mapped user on success', () async {
      final user = _user();
      when(
        () => auth.signInWithPassword(email: 'a@b.co', password: 'pw'),
      ).thenAnswer((_) async => AuthResponse(session: _session(user)));

      final result = await source.signIn(email: 'a@b.co', password: 'pw');

      expect(result, isA<Success<AppUser>>());
      expect(
        (result as Success<AppUser>).value,
        const AppUser(id: 'u1', email: 'a@b.co'),
      );
    });

    const cases = <String, String>{
      'invalid_credentials': ErrorCodes.invalidCredentials,
      'email_not_confirmed': ErrorCodes.emailNotConfirmed,
      'over_request_rate_limit': ErrorCodes.rateLimited,
    };
    for (final entry in cases.entries) {
      test('P1-2: maps ${entry.key} to ${entry.value}', () async {
        when(
          () => auth.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(
          AuthApiException('x', statusCode: '400', code: entry.key),
        );

        final result = await source.signIn(email: 'a@b.co', password: 'pw');

        expect(result, isA<Failure<AppUser>>());
        expect((result as Failure<AppUser>).error.code, entry.value);
      });
    }

    test('P1-2: maps a fetch failure to network', () async {
      when(
        () => auth.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(AuthRetryableFetchException());

      final result = await source.signIn(email: 'a@b.co', password: 'pw');

      expect((result as Failure<AppUser>).error.code, ErrorCodes.network);
    });

    test('P1-2: maps an unexpected error to internal', () async {
      when(
        () => auth.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(StateError('bug'));

      final result = await source.signIn(email: 'a@b.co', password: 'pw');

      expect((result as Failure<AppUser>).error.code, ErrorCodes.internal);
    });

    test('P1-2: returns internal when the response has no user', () async {
      when(
        () => auth.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => AuthResponse());

      final result = await source.signIn(email: 'a@b.co', password: 'pw');

      expect((result as Failure<AppUser>).error.code, ErrorCodes.internal);
    });
  });

  group('P1-2: signUp', () {
    test('P1-2: returns signedIn when a session is returned', () async {
      when(
        () => auth.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => AuthResponse(session: _session(_user())));

      final result = await source.signUp(
        email: 'a@b.co',
        password: 'pw',
        fullName: 'Sam Ali',
      );

      expect((result as Success<SignUpOutcome>).value, SignUpOutcome.signedIn);
    });

    test('P1-2: returns confirmationSent when session is null', () async {
      when(
        () => auth.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => AuthResponse(user: _user()));

      final result = await source.signUp(
        email: 'a@b.co',
        password: 'pw',
        fullName: 'Sam Ali',
      );

      expect(
        (result as Success<SignUpOutcome>).value,
        SignUpOutcome.confirmationSent,
      );
    });

    test('P1-2: confirmationSent for a new user with identities', () async {
      when(
        () => auth.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => AuthResponse(
          user: _user(
            identities: [
              const UserIdentity(
                identityId: 'i1',
                id: 'u1',
                userId: 'u1',
                identityData: {},
                provider: 'email',
                createdAt: '2026-10-01T00:00:00Z',
                lastSignInAt: '2026-10-01T00:00:00Z',
              ),
            ],
          ),
        ),
      );

      final result = await source.signUp(
        email: 'a@b.co',
        password: 'pw',
        fullName: 'Sam Ali',
      );

      expect(
        (result as Success<SignUpOutcome>).value,
        SignUpOutcome.confirmationSent,
      );
    });

    test('P1-2: existing account (empty identities) is emailTaken', () async {
      when(
        () => auth.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => AuthResponse(user: _user(identities: const [])),
      );

      final result = await source.signUp(
        email: 'a@b.co',
        password: 'pw',
        fullName: 'Sam Ali',
      );

      expect(
        (result as Failure<SignUpOutcome>).error.code,
        ErrorCodes.emailTaken,
      );
    });

    test('P1-2: sends full_name as user metadata', () async {
      when(
        () => auth.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => AuthResponse(user: _user()));

      await source.signUp(
        email: 'a@b.co',
        password: 'pw',
        fullName: 'Sam Ali',
      );

      verify(
        () => auth.signUp(
          email: 'a@b.co',
          password: 'pw',
          data: {'full_name': 'Sam Ali'},
        ),
      ).called(1);
    });

    const cases = <String, String>{
      'user_already_exists': ErrorCodes.emailTaken,
      'email_exists': ErrorCodes.emailTaken,
      'weak_password': ErrorCodes.weakPassword,
    };
    for (final entry in cases.entries) {
      test('P1-2: maps ${entry.key} to ${entry.value}', () async {
        when(
          () => auth.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
            data: any(named: 'data'),
          ),
        ).thenThrow(
          AuthApiException('x', statusCode: '422', code: entry.key),
        );

        final result = await source.signUp(
          email: 'a@b.co',
          password: 'pw',
          fullName: 'Sam Ali',
        );

        expect(
          (result as Failure<SignUpOutcome>).error.code,
          entry.value,
        );
      });
    }
  });

  group('P1-2: signOut', () {
    test('P1-2: returns success when sign out completes', () async {
      when(() => auth.signOut()).thenAnswer((_) async {});

      expect(await source.signOut(), isA<Success<void>>());
    });

    test('P1-2: maps a thrown error to a failure', () async {
      when(() => auth.signOut()).thenThrow(AuthRetryableFetchException());

      final result = await source.signOut();

      expect((result as Failure<void>).error.code, ErrorCodes.network);
    });
  });

  group('P1-2: currentUser and userChanges', () {
    test('P1-2: currentUser is null when signed out', () {
      when(() => auth.currentUser).thenReturn(null);

      expect(source.currentUser, isNull);
    });

    test('P1-2: currentUser maps the gotrue user', () {
      when(() => auth.currentUser).thenReturn(_user());

      expect(source.currentUser, const AppUser(id: 'u1', email: 'a@b.co'));
    });

    test('P1-2: userChanges maps session to user and signed out to null', () {
      final controller = StreamController<AuthState>();
      addTearDown(controller.close);
      when(() => auth.onAuthStateChange).thenAnswer((_) => controller.stream);

      final future = source.userChanges.take(2).toList();
      controller
        ..add(AuthState(AuthChangeEvent.signedIn, _session(_user())))
        ..add(const AuthState(AuthChangeEvent.signedOut, null));

      expect(
        future,
        completion([const AppUser(id: 'u1', email: 'a@b.co'), null]),
      );
    });

    test('P1-2: userChanges emits equal consecutive users once', () {
      final controller = StreamController<AuthState>();
      addTearDown(controller.close);
      when(() => auth.onAuthStateChange).thenAnswer((_) => controller.stream);

      final future = source.userChanges.take(2).toList();
      controller
        ..add(AuthState(AuthChangeEvent.signedIn, _session(_user())))
        ..add(AuthState(AuthChangeEvent.tokenRefreshed, _session(_user())))
        ..add(const AuthState(AuthChangeEvent.signedOut, null));

      expect(
        future,
        completion([const AppUser(id: 'u1', email: 'a@b.co'), null]),
      );
    });

    test('P1-2: userChanges drops stream errors and keeps going', () {
      final controller = StreamController<AuthState>();
      addTearDown(controller.close);
      when(() => auth.onAuthStateChange).thenAnswer((_) => controller.stream);

      final future = source.userChanges.take(2).toList();
      controller
        ..add(AuthState(AuthChangeEvent.signedIn, _session(_user())))
        ..addError(AuthRetryableFetchException())
        ..add(const AuthState(AuthChangeEvent.signedOut, null));

      expect(
        future,
        completion([const AppUser(id: 'u1', email: 'a@b.co'), null]),
      );
    });
  });
}
