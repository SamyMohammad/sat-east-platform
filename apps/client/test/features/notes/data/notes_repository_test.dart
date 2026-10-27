import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/notes/data/datasources/notes_remote_data_source.dart';
import 'package:sat_east_client/features/notes/data/repositories/notes_repository_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('L-3: exact storage path and mark RPC contract', () async {
    final paths = <String>[];
    final calls = <(String, Map<String, Object?>)>[];
    final repo = NotesRepositoryImpl(
      NotesRemoteDataSource(
        (path) async {
          paths.add(path);
          return Uint8List.fromList([1, 2]);
        },
        (fn, params) async {
          calls.add((fn, params));
          return {'notes_opened_at': '2026-10-27T00:00:00Z'};
        },
      ),
    );
    expect((await repo.download('t1/a1.pdf') as Success<Uint8List>).value, [
      1,
      2,
    ]);
    expect(await repo.markOpened('a1'), isA<Success<void>>());
    expect(paths, ['t1/a1.pdf']);
    expect(calls.single.$1, 'mark_notes_opened');
    expect(calls.single.$2, {'p_asset_id': 'a1'});
  });
  for (final code in [
    'topic_locked',
    'not_enrolled',
    'invalid_input',
    'not_authenticated',
  ]) {
    test('L-3: RPC $code mapped', () async {
      final repo = NotesRepositoryImpl(
        NotesRemoteDataSource(
          (_) async => Uint8List(1),
          (_, _) async => throw PostgrestException(message: code),
        ),
      );
      expect((await repo.markOpened('a1') as Failure<void>).error.code, code);
    });
    test('L-3: Storage $code mapped', () async {
      final repo = NotesRepositoryImpl(
        NotesRemoteDataSource(
          (_) async => throw StorageException(code, statusCode: '403'),
          (_, _) async => null,
        ),
      );
      expect(
        (await repo.download('t1/a1.pdf') as Failure<Uint8List>).error.code,
        code,
      );
    });
  }
  test('L-3: transport failures map to network', () async {
    final repo = NotesRepositoryImpl(
      NotesRemoteDataSource(
        (_) async => throw TimeoutException('offline'),
        (_, _) async => throw TimeoutException('offline'),
      ),
    );
    expect(
      (await repo.download('t1/a1.pdf') as Failure<Uint8List>).error.code,
      'network',
    );
    expect(
      (await repo.markOpened('a1') as Failure<void>).error.code,
      'network',
    );
  });
  test('L-3: malformed mark response is internal', () async {
    final repo = NotesRepositoryImpl(
      NotesRemoteDataSource((_) async => Uint8List(1), (_, _) async => {}),
    );
    expect(
      (await repo.markOpened('a1') as Failure<void>).error.code,
      'internal',
    );
  });
}
