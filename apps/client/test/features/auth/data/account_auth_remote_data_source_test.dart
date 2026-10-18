import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:sat_east_client/features/auth/domain/entities/my_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fakes.dart';

User _user({String? email = 'student@example.com'}) => User(
  id: 'student-id',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-10-18T00:00:00Z',
  email: email,
);

void main() {
  late MockGoTrueClient auth;
  late AuthRemoteDataSource source;

  setUpAll(() => registerFallbackValue(UserAttributes()));
  setUp(() {
    auth = MockGoTrueClient();
    source = AuthRemoteDataSource(auth, client: MockSupabaseClient());
  });

  group('AUTH-06: requestPasswordReset', () {
    test('AUTH-06: web reset uses the origin and recovery marker', () async {
      source = AuthRemoteDataSource(
        auth,
        client: MockSupabaseClient(),
        isWeb: true,
        baseUri: Uri.parse('https://app.test/?old=value#/sign-in'),
      );
      when(
        () => auth.resetPasswordForEmail(
          'student@example.com',
          redirectTo: 'https://app.test/?flow=recovery',
        ),
      ).thenAnswer((_) async {});
      expect(
        await source.requestPasswordReset('student@example.com'),
        isA<Success<void>>(),
      );
      verify(
        () => auth.resetPasswordForEmail(
          'student@example.com',
          redirectTo: 'https://app.test/?flow=recovery',
        ),
      ).called(1);
    });

    test('AUTH-06: native reset leaves redirect unset', () async {
      when(
        () => auth.resetPasswordForEmail('student@example.com'),
      ).thenAnswer((_) async {});
      expect(
        await source.requestPasswordReset('student@example.com'),
        isA<Success<void>>(),
      );
    });

    test('AUTH-06: unknown email has the same success result', () async {
      when(() => auth.resetPasswordForEmail(any())).thenThrow(
        const AuthApiException(
          'User not found',
          code: 'user_not_found',
          statusCode: '404',
        ),
      );
      expect(
        await source.requestPasswordReset('unknown@example.com'),
        isA<Success<void>>(),
      );
    });

    final failures = <(Object, String)>[
      (
        const AuthApiException('limited', code: 'over_email_send_rate_limit'),
        ErrorCodes.rateLimited,
      ),
      (
        const AuthApiException('limited', code: 'over_request_rate_limit'),
        ErrorCodes.rateLimited,
      ),
      (AuthRetryableFetchException(), ErrorCodes.network),
      (const SocketException('offline'), ErrorCodes.network),
      (const AuthException('unexpected'), ErrorCodes.internal),
      (StateError('unexpected'), ErrorCodes.internal),
    ];
    for (var i = 0; i < failures.length; i++) {
      final (error, code) = failures[i];
      test('AUTH-06: reset maps failure $i to $code', () async {
        when(() => auth.resetPasswordForEmail(any())).thenThrow(error);
        final result = await source.requestPasswordReset('student@example.com');
        expect((result as Failure<void>).error.code, code);
      });
    }
  });

  for (final (error, code) in <(Object, String)>[
    (
      const AuthApiException('expired', code: 'otp_expired'),
      ErrorCodes.linkExpired,
    ),
    (
      const AuthApiException('expired', code: 'flow_state_expired'),
      ErrorCodes.linkExpired,
    ),
    (const AuthPKCEGrantCodeExchangeError('used'), ErrorCodes.linkExpired),
    (AuthRetryableFetchException(), ErrorCodes.network),
    (StateError('unexpected'), ErrorCodes.internal),
  ]) {
    test('AUTH-06: recovery stream maps $error to $code', () async {
      final events = StreamController<AuthState>();
      addTearDown(events.close);
      when(() => auth.onAuthStateChange).thenAnswer((_) => events.stream);
      final assertion = expectLater(
        source.passwordRecovery,
        emitsError(isA<AppError>().having((e) => e.code, 'code', code)),
      );
      events.addError(error);
      await assertion;
    });
  }

  group('AUTH-06: updatePassword', () {
    test(
      'AUTH-06: signed-out SDK exception maps to not_authenticated',
      () async {
        when(
          () => auth.updateUser(any()),
        ).thenThrow(AuthSessionMissingException());
        final result = await source.updatePassword('new-password');
        expect(
          (result as Failure<void>).error.code,
          ErrorCodes.notAuthenticated,
        );
      },
    );
    test('AUTH-06: updates only the password', () async {
      when(
        () => auth.updateUser(any()),
      ).thenAnswer((_) async => UserResponse.fromJson(_user().toJson()));
      expect(await source.updatePassword('new-password'), isA<Success<void>>());
      final attributes =
          verify(() => auth.updateUser(captureAny())).captured.single
              as UserAttributes;
      expect(attributes.toJson(), {'password': 'new-password'});
    });

    final failures = <(Object, String)>[
      (
        const AuthApiException('weak', code: 'weak_password'),
        ErrorCodes.weakPassword,
      ),
      (
        const AuthApiException('limited', code: 'over_request_rate_limit'),
        ErrorCodes.rateLimited,
      ),
      (
        const AuthApiException('signed out', code: 'session_not_found'),
        ErrorCodes.notAuthenticated,
      ),
      (
        const AuthApiException('expired', code: 'session_expired'),
        ErrorCodes.notAuthenticated,
      ),
      (
        const AuthApiException('missing', code: 'refresh_token_not_found'),
        ErrorCodes.notAuthenticated,
      ),
      (AuthRetryableFetchException(), ErrorCodes.network),
      (const SocketException('offline'), ErrorCodes.network),
      (const AuthException('unexpected'), ErrorCodes.internal),
      (StateError('unexpected'), ErrorCodes.internal),
    ];
    for (var i = 0; i < failures.length; i++) {
      final (error, code) = failures[i];
      test('AUTH-06: password update maps failure $i to $code', () async {
        when(() => auth.updateUser(any())).thenThrow(error);
        final result = await source.updatePassword('new-password');
        expect((result as Failure<void>).error.code, code);
      });
    }
  });

  test(
    'AUTH-06: recovery stream delivers a late recovery event only',
    () async {
      final events = StreamController<AuthState>();
      addTearDown(events.close);
      when(() => auth.onAuthStateChange).thenAnswer((_) => events.stream);
      final result = source.passwordRecovery.toList();
      final session = Session(
        accessToken: 'test-token',
        tokenType: 'bearer',
        user: _user(),
      );
      events
        ..add(const AuthState(AuthChangeEvent.initialSession, null))
        ..add(const AuthState(AuthChangeEvent.signedOut, null))
        ..add(AuthState(AuthChangeEvent.signedIn, session))
        ..add(AuthState(AuthChangeEvent.passwordRecovery, session))
        ..add(AuthState(AuthChangeEvent.tokenRefreshed, session));
      await events.close();
      expect(await result, hasLength(1));
    },
  );

  group('S-34: getMyProfile', () {
    late Object? payload;
    late Object? error;
    late int status;
    late List<http.Request> requests;
    setUp(() {
      payload = {'full_name': 'Student Name'};
      error = null;
      status = 200;
      requests = [];
      final client = SupabaseClient(
        'https://api.test',
        'test-key',
        httpClient: MockClient((request) async {
          requests.add(request);
          if (error != null) {
            // Fixture throws arbitrary objects to test error mapping.
            // ignore: only_throw_errors
            throw error!;
          }
          return http.Response(
            jsonEncode(payload),
            status,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(client.dispose);
      source = AuthRemoteDataSource(auth, client: client);
      when(() => auth.currentUser).thenReturn(_user());
    });

    test('S-34: reads own stored name and auth email', () async {
      final profile = (await source.getMyProfile() as Success<MyProfile>).value;
      expect(profile.fullName, 'Student Name');
      expect(profile.email, 'student@example.com');
      expect(requests.single.url.path, '/rest/v1/profiles');
      expect(requests.single.url.queryParameters, {
        'select': 'full_name',
        'id': 'eq.student-id',
      });
    });

    test(
      'S-34: signed out returns not_authenticated without querying',
      () async {
        when(() => auth.currentUser).thenReturn(null);
        expect(
          (await source.getMyProfile() as Failure<MyProfile>).error.code,
          ErrorCodes.notAuthenticated,
        );
        expect(requests, isEmpty);
      },
    );

    test('S-34: absent email returns internal without querying', () async {
      when(() => auth.currentUser).thenReturn(_user(email: null));
      expect(
        (await source.getMyProfile() as Failure<MyProfile>).error.code,
        ErrorCodes.internal,
      );
      expect(requests, isEmpty);
    });

    for (final failure in <(AuthException, String)>[
      (AuthSessionMissingException(), ErrorCodes.notAuthenticated),
      (AuthRetryableFetchException(), ErrorCodes.network),
      (const AuthException('unexpected'), ErrorCodes.internal),
    ]) {
      test('S-34: maps profile auth failure ${failure.$2}', () async {
        when(() => auth.currentUser).thenThrow(failure.$1);
        expect(
          (await source.getMyProfile() as Failure<MyProfile>).error.code,
          failure.$2,
        );
        expect(requests, isEmpty);
      });
    }

    for (final malformed in <Object?>[
      null,
      <String, Object?>{},
      {'full_name': 4},
    ]) {
      test('S-34: malformed profile $malformed returns internal', () async {
        payload = malformed;
        expect(
          (await source.getMyProfile() as Failure<MyProfile>).error.code,
          ErrorCodes.internal,
        );
      });
    }

    for (final code in [
      ErrorCodes.notAuthenticated,
      ErrorCodes.forbidden,
      ErrorCodes.internal,
    ]) {
      test('S-34: maps profile RPC error $code', () async {
        status = 400;
        payload = {'message': code, 'code': 'P0001'};
        expect(
          (await source.getMyProfile() as Failure<MyProfile>).error.code,
          code,
        );
      });
    }

    for (final failure in <(Object, String)>[
      (const SocketException('offline'), ErrorCodes.network),
      (StateError('unexpected'), ErrorCodes.internal),
    ]) {
      test('S-34: maps profile transport ${failure.$2}', () async {
        error = failure.$1;
        expect(
          (await source.getMyProfile() as Failure<MyProfile>).error.code,
          failure.$2,
        );
      });
    }
  });
}
