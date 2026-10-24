import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/questions/data/datasources/question_bank_remote_data_source.dart';
import 'package:sat_east_client/features/teacher/questions/data/repositories/question_bank_repository_impl.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/bank_filter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/fakes/fake_rpc.dart';
import '../bank_fixtures.dart';

void main() {
  test('QB-06: list uses exact teacher RPC contract', () async {
    final rpc = FakeRpc()..response = bankJson;
    final repo = QuestionBankRepositoryImpl(
      QuestionBankRemoteDataSource(rpc.call),
    );
    expect(
      (await repo.list(const BankFilter(q: 'A_%'), 2) as Success).value,
      bankPage,
    );
    expect(rpc.calls.single.$1, 'teacher_list_questions');
    expect(
      rpc.calls.single.$2,
      equals({
        'p_filter': {'q': 'A_%'},
        'p_page': 2,
      }),
    );
  });
  test('QB-06: topics uses teacher tree read', () async {
    final rpc = FakeRpc()..response = topicsJson;
    final repo = QuestionBankRepositoryImpl(
      QuestionBankRemoteDataSource(rpc.call),
    );
    expect((await repo.topics() as Success).value, bankTopics);
    expect(rpc.calls.single.$1, 'teacher_list_topics_tree');
    expect(rpc.calls.single.$2, isEmpty);
  });
  for (final tree in [false, true]) {
    for (final code in ['forbidden', 'not_authenticated', 'invalid_input']) {
      test('QB-06: maps $code for tree=$tree', () async {
        final rpc = FakeRpc()..error = PostgrestException(message: code);
        final repo = QuestionBankRepositoryImpl(
          QuestionBankRemoteDataSource(rpc.call),
        );
        expect(
          ((tree ? await repo.topics() : await repo.list(const BankFilter(), 1))
                  as Failure)
              .error
              .code,
          code,
        );
      });
    }
    test('QB-06: maps transport errors for tree=$tree', () async {
      final rpc = FakeRpc()..error = const SocketException('offline');
      final repo = QuestionBankRepositoryImpl(
        QuestionBankRemoteDataSource(rpc.call),
      );
      expect(
        ((tree ? await repo.topics() : await repo.list(const BankFilter(), 1))
                as Failure)
            .error
            .code,
        'network',
      );
    });
    test('QB-06: malformed response is internal for tree=$tree', () async {
      final rpc = FakeRpc();
      final repo = QuestionBankRepositoryImpl(
        QuestionBankRemoteDataSource(rpc.call),
      );
      expect(
        ((tree ? await repo.topics() : await repo.list(const BankFilter(), 1))
                as Failure)
            .error
            .code,
        'internal',
      );
    });
  }
}
