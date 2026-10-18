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
import 'package:sat_east_client/features/auth/domain/entities/my_enrollment.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fakes.dart';

const _row = <String, Object?>{
  'target_test_date': '2027-03-15',
  'expires_at': '2027-03-30T00:00:00Z',
  'status': 'active',
  'courses': {'title': 'SAT Math'},
};
final _now = DateTime.utc(2026, 10, 18, 12);

void main() {
  late MockGoTrueClient auth;
  late AuthRemoteDataSource source;
  late Object? payload;
  late Object? error;
  late int status;
  late List<http.Request> requests;

  setUp(() {
    auth = MockGoTrueClient();
    payload = [_row];
    error = null;
    status = 200;
    requests = [];
    final client = SupabaseClient(
      'https://api.test',
      'test-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (error != null) {
          // Fixtures inject arbitrary exceptions to verify boundary mapping.
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
    source = AuthRemoteDataSource(auth, client: client, now: () => _now);
    when(() => auth.currentUser).thenReturn(
      const User(
        id: 'student-id',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-10-18T00:00:00Z',
      ),
    );
  });

  Future<List<MyEnrollment>> load() async =>
      (await source.listMyEnrollments() as Success<List<MyEnrollment>>).value;

  test('AUTH-02: queries own enrollments newest access end first', () async {
    final enrollments = await load();

    expect(requests.single.url.path, '/rest/v1/enrollments');
    expect(requests.single.url.queryParameters, {
      'select': 'target_test_date,expires_at,status,courses(title)',
      'user_id': 'eq.student-id',
      'order': 'expires_at.desc.nullslast',
    });
    final enrollment = enrollments.single;
    expect(enrollment.courseTitle, 'SAT Math');
    expect(enrollment.targetTestDate, DateTime(2027, 3, 15));
    expect(enrollment.expiresAt, DateTime.utc(2027, 3, 30));
    expect(enrollment.isExpired, isFalse);
  });

  test('AUTH-02: null target test date stays absent', () async {
    payload = [
      {..._row, 'target_test_date': null},
    ];

    expect((await load()).single.targetTestDate, isNull);
  });

  for (final (label, row, expired) in <(String, Map<String, Object?>, bool)>[
    ('future active', _row, false),
    (
      'past active',
      {..._row, 'expires_at': '2026-10-18T11:59:59Z'},
      true,
    ),
    (
      'boundary active',
      {..._row, 'expires_at': '2026-10-18T12:00:00Z'},
      true,
    ),
    ('future expired status', {..._row, 'status': 'expired'}, true),
    ('future refunded status', {..._row, 'status': 'refunded'}, true),
  ]) {
    test('AUTH-02: $label maps expiry against injected clock', () async {
      payload = [row];

      expect((await load()).single.isExpired, expired);
    });
  }

  test('AUTH-02: an empty enrollment response succeeds', () async {
    payload = <Object?>[];

    expect(await load(), isEmpty);
  });

  test('AUTH-02: hidden course rows do not hide visible enrollments', () async {
    payload = [
      {..._row, 'courses': null},
      _row,
    ];

    final enrollments = await load();

    expect(enrollments, hasLength(1));
    expect(enrollments.single.courseTitle, 'SAT Math');
  });

  test('AUTH-02: signed out fails without querying', () async {
    when(() => auth.currentUser).thenReturn(null);

    final result = await source.listMyEnrollments();

    expect((result as Failure).error.code, ErrorCodes.notAuthenticated);
    expect(requests, isEmpty);
  });

  for (final (failure, code) in <(AuthException, String)>[
    (AuthSessionMissingException(), ErrorCodes.notAuthenticated),
    (AuthRetryableFetchException(), ErrorCodes.network),
    (const AuthException('unexpected'), ErrorCodes.internal),
  ]) {
    test('AUTH-02: enrollment auth error maps to $code', () async {
      when(() => auth.currentUser).thenThrow(failure);

      final result = await source.listMyEnrollments();

      expect((result as Failure).error.code, code);
      expect(requests, isEmpty);
    });
  }

  for (final code in [
    ErrorCodes.notAuthenticated,
    ErrorCodes.forbidden,
    ErrorCodes.internal,
  ]) {
    test('AUTH-02: enrollment PostgREST error maps to $code', () async {
      status = 400;
      payload = {'message': code, 'code': 'P0001'};

      final result = await source.listMyEnrollments();

      expect((result as Failure).error, AppError(code, code));
    });
  }

  for (final (failure, code) in <(Object, String)>[
    (const SocketException('offline'), ErrorCodes.network),
    (TimeoutException('offline'), ErrorCodes.network),
    (http.ClientException('offline'), ErrorCodes.network),
    (StateError('unexpected'), ErrorCodes.internal),
  ]) {
    test('AUTH-02: enrollment transport error maps to $code', () async {
      error = failure;

      final result = await source.listMyEnrollments();

      expect((result as Failure).error.code, code);
    });
  }

  for (final malformed in <Object?>[
    null,
    <String, Object?>{},
    [4],
    [
      {..._row, 'courses': <Object?>[]},
    ],
    [
      {
        ..._row,
        'courses': {'title': null},
      },
    ],
    [
      {..._row, 'target_test_date': 4},
    ],
    [
      {..._row, 'target_test_date': 'not-a-date'},
    ],
    [
      {..._row, 'expires_at': null},
    ],
    [
      {..._row, 'expires_at': 'not-a-date'},
    ],
    [
      {..._row, 'status': null},
    ],
    [
      {..._row, 'status': 'unknown'},
    ],
    [
      {
        for (final entry in _row.entries)
          if (entry.key != 'courses') entry.key: entry.value,
      },
    ],
  ]) {
    test('AUTH-02: malformed enrollment $malformed fails safely', () async {
      payload = malformed;

      final result = await source.listMyEnrollments();

      expect((result as Failure).error.code, ErrorCodes.internal);
    });
  }
}
