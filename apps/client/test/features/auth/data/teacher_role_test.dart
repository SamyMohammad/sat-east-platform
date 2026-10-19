import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:sat_east_client/features/auth/domain/entities/app_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fakes.dart';

void main() {
  const user = User(
    id: 'u1',
    email: 'teacher@example.com',
    appMetadata: {},
    userMetadata: {'role': 'teacher'},
    aud: 'authenticated',
    createdAt: '2026-10-19T00:00:00Z',
  );

  for (final role in ['teacher', 'student', 'admin', null, 1]) {
    for (final signIn in [false, true]) {
      test('ADM-01: ${signIn ? 'sign in' : 'restore'} role $role', () async {
        final auth = MockGoTrueClient();
        when(() => auth.currentUser).thenReturn(user);
        when(
          () => auth.signInWithPassword(email: 'email', password: 'pw'),
        ).thenAnswer((_) async => AuthResponse(user: user));
        late Uri requestUri;
        final client = SupabaseClient(
          'https://example.test',
          'public-key',
          httpClient: MockClient((request) async {
            requestUri = request.url;
            return http.Response(
              jsonEncode([
                {'role': role},
              ]),
              200,
              request: request,
            );
          }),
        );
        addTearDown(client.dispose);
        final source = AuthRemoteDataSource(auth, client: client);
        final actual = signIn
            ? (await source.signIn(email: 'email', password: 'pw')
                      as Success<AppUser>)
                  .value
            : await source.getCurrentUser();
        expect(requestUri.path, '/rest/v1/profiles');
        expect(requestUri.queryParameters['select'], 'role');
        expect(requestUri.queryParameters['id'], 'eq.u1');
        expect(actual?.id, 'u1');
        expect(actual?.isTeacher, role == 'teacher');
      });
    }
  }

  for (final status in [403, 500]) {
    test('ADM-01: role failure $status preserves the session', () async {
      final auth = MockGoTrueClient();
      when(() => auth.currentUser).thenReturn(user);
      when(
        () => auth.signInWithPassword(email: 'email', password: 'pw'),
      ).thenAnswer((_) async => AuthResponse(user: user));
      final client = SupabaseClient(
        'https://example.test',
        'public-key',
        httpClient: MockClient((_) async => http.Response('{}', status)),
      );
      addTearDown(client.dispose);
      final source = AuthRemoteDataSource(auth, client: client);
      expect((await source.getCurrentUser())?.isTeacher, isFalse);
      final result = await source.signIn(email: 'email', password: 'pw');
      expect((result as Success<AppUser>).value.isTeacher, isFalse);
      verifyNever(auth.signOut);
    });
  }

  for (final missing in [false, true]) {
    test(
      'ADM-01: missing row or transport failure stays signed in $missing',
      () async {
        final auth = MockGoTrueClient();
        when(() => auth.currentUser).thenReturn(user);
        final client = SupabaseClient(
          'https://example.test',
          'public-key',
          httpClient: MockClient((request) async {
            if (missing) return http.Response('[]', 200, request: request);
            throw StateError('Transport unavailable');
          }),
        );
        addTearDown(client.dispose);
        final source = AuthRemoteDataSource(auth, client: client);
        final actual = await source.getCurrentUser();
        expect(actual?.id, user.id);
        expect(actual?.isTeacher, isFalse);
        verifyNever(auth.signOut);
      },
    );
  }

  test('ADM-01: signed out restore does not query profiles', () async {
    final auth = MockGoTrueClient();
    when(() => auth.currentUser).thenReturn(null);
    final client = MockSupabaseClient();
    final source = AuthRemoteDataSource(auth, client: client);
    expect(await source.getCurrentUser(), isNull);
    verifyNever(() => client.from(any()));
  });

  test('ADM-01: teacher role participates in user equality', () {
    const student = AppUser(id: 'u1', email: 'email');
    const teacher = AppUser(id: 'u1', email: 'email', isTeacher: true);
    expect(student.isTeacher, isFalse);
    expect(student, isNot(teacher));
  });
}
