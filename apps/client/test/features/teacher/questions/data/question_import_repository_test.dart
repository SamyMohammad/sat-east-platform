import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/questions/data/datasources/question_import_remote_data_source.dart';
import 'package:sat_east_client/features/teacher/questions/data/repositories/question_import_repository_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/fakes/fake_rpc.dart';
import '../import_fixtures.dart';

void main() {
  for (final commit in [false, true]) {
    test('QB-05: RPC forwards untouched rows and commit=$commit', () async {
      final rpc = FakeRpc()..response = reportJson;
      final repo = QuestionImportRepositoryImpl(
        QuestionImportRemoteDataSource(rpc.call),
      );
      final items = <Object?>[
        {
          'unexpected': [null, true, 3.5],
        },
        null,
      ];
      final result = commit
          ? await repo.commit(items)
          : await repo.dryRun(items);
      expect((result as Success).value, cleanReport);
      expect(rpc.calls.single.$1, 'teacher_import_questions');
      expect(
        rpc.calls.single.$2,
        equals({'p_items': items, 'p_commit': commit}),
      );
      expect(rpc.calls.single.$2['p_items'], same(items));
    });
    for (final code in ['forbidden', 'invalid_input', 'not_authenticated']) {
      test('QB-05: maps $code commit=$commit', () async {
        final rpc = FakeRpc()..error = PostgrestException(message: code);
        final repo = QuestionImportRepositoryImpl(
          QuestionImportRemoteDataSource(rpc.call),
        );
        final result = commit ? await repo.commit([]) : await repo.dryRun([]);
        expect((result as Failure).error.code, code);
      });
    }
    test('QB-05: maps transport error commit=$commit', () async {
      final rpc = FakeRpc()..error = const SocketException('offline');
      final repo = QuestionImportRepositoryImpl(
        QuestionImportRemoteDataSource(rpc.call),
      );
      expect(
        ((commit ? await repo.commit([]) : await repo.dryRun([])) as Failure)
            .error
            .code,
        'network',
      );
    });
    test('QB-05: malformed response becomes internal commit=$commit', () async {
      final rpc = FakeRpc();
      final repo = QuestionImportRepositoryImpl(
        QuestionImportRemoteDataSource(rpc.call),
      );
      expect(
        ((commit ? await repo.commit([]) : await repo.dryRun([])) as Failure)
            .error
            .code,
        'internal',
      );
    });
  }
}
