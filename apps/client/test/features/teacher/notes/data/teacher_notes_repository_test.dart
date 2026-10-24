import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/notes/data/datasources/teacher_notes_remote_data_source.dart';
import 'package:sat_east_client/features/teacher/notes/data/repositories/teacher_notes_repository_impl.dart';
import 'package:sat_east_client/features/teacher/notes/domain/entities/teacher_note.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'C-3: reads metadata and numeric settings and sends exact RPC contracts',
    () async {
      final calls = <(String, Map<String, Object?>)>[];
      final storage = <String>[];
      final repo = TeacherNotesRepositoryImpl(
        TeacherNotesRemoteDataSource(
          rpc: (fn, params) async {
            calls.add((fn, params));
            return fn == 'teacher_create_notes_asset'
                ? {'asset_id': 'a1', 'path': 't1/a1.pdf'}
                : {'ok': true};
          },
          readNotes: (topic) async {
            expect(topic, 't1');
            return [
              {
                'id': 'a1',
                'title': 'Notes',
                'subtopic_id': null,
                'page_count': 3,
                'ready': true,
              },
            ];
          },
          readLimit: () async => {'value': 7},
          uploadBytes: (path, bytes) async {
            storage.add('upload:$path:${bytes.length}');
          },
          removeObject: (path) async {
            storage.add('remove:$path');
          },
        ),
      );
      expect(
        (await repo.list('t1') as Success<List<TeacherNote>>)
            .value
            .single
            .title,
        'Notes',
      );
      expect((await repo.maxUploadMb() as Success<int>).value, 7);
      expect(
        (await repo.create('t1', 'Notes', 3) as Success<CreatedNote>)
            .value
            .path,
        't1/a1.pdf',
      );
      await repo.upload('t1/a1.pdf', Uint8List(2));
      await repo.confirm('a1');
      await repo.update('a1', 'New', 's1');
      await repo.reorder('t1', ['a1']);
      await repo.remove('t1/a1.pdf');
      await repo.delete('a1');
      expect(calls.map((call) => call.$1), [
        'teacher_create_notes_asset',
        'teacher_confirm_notes_asset',
        'teacher_update_notes_asset',
        'teacher_reorder_notes',
        'teacher_delete_notes_asset',
      ]);
      expect(calls.map((call) => call.$2), [
        {
          'p_topic_id': 't1',
          'p_subtopic_id': null,
          'p_title': 'Notes',
          'p_page_count': 3,
        },
        {'p_asset_id': 'a1'},
        {'p_asset_id': 'a1', 'p_title': 'New', 'p_subtopic_id': 's1'},
        {
          'p_topic_id': 't1',
          'p_ids': ['a1'],
        },
        {'p_asset_id': 'a1'},
      ]);
      expect(storage, ['upload:t1/a1.pdf:2', 'remove:t1/a1.pdf']);
    },
  );
  for (final code in ['forbidden', 'invalid_input', 'not_authenticated']) {
    test('C-3: maps $code from RPC', () async {
      final repo = failingRepo(PostgrestException(message: code));
      expect((await repo.delete('a1') as Failure<void>).error.code, code);
    });
  }
  test('C-3: storage missing object is safe for cleanup and delete', () async {
    expect(
      await failingRepo(
        const StorageException('missing', statusCode: '404'),
      ).remove('t1/a1.pdf'),
      isA<Success<void>>(),
    );
  });
  test('C-3: storage denied is surfaced', () async {
    expect(
      (await failingRepo(
                const StorageException('denied', statusCode: '403'),
              ).upload('t1/a1.pdf', Uint8List(1))
              as Failure<void>)
          .error
          .code,
      'forbidden',
    );
  });
  test('C-3: transport maps to network', () async {
    expect(
      (await failingRepo(TimeoutException('offline')).list('t1')
              as Failure<List<TeacherNote>>)
          .error
          .code,
      'network',
    );
  });
  test('C-3: malformed setting fails closed', () async {
    final source = TeacherNotesRemoteDataSource(
      rpc: (_, _) async => null,
      readNotes: (_) async => [],
      readLimit: () async => {'value': '20'},
      uploadBytes: (_, _) async {},
      removeObject: (_) async {},
    );
    expect((await source.maxUploadMb() as Failure<int>).error.code, 'internal');
  });
}

TeacherNotesRepositoryImpl failingRepo(Exception error) =>
    TeacherNotesRepositoryImpl(
      TeacherNotesRemoteDataSource(
        rpc: (_, _) async => throw error,
        readNotes: (_) async => throw error,
        readLimit: () async => throw error,
        uploadBytes: (_, _) async => throw error,
        removeObject: (_) async => throw error,
      ),
    );
