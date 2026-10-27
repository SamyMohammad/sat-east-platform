import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/attempts/save_outcome.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/homework/data/datasources/homework_remote_data_source.dart';
import 'package:sat_east_client/features/homework/data/models/homework_model.dart';
import 'package:sat_east_client/features/homework/data/repositories/homework_repository_impl.dart';
import 'package:sat_east_client/features/homework/domain/entities/homework.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/fakes/fake_rpc.dart';
import '../homework_fixture.dart';

void main() {
  test('PRC-02: untimed session parses answers and marks', () {
    expect(homeworkSessionFromJson(homeworkPayload()), homeworkSession);
  });
  test('PRC-02: homework report needs no pass mark or deadline', () {
    expect(homeworkReportFromJson(homeworkReportPayload()), homeworkReport);
  });
  for (final field in ['questions', 'answers', 'client_seq', 'attempt_id']) {
    test('PRC-02: rejects malformed $field', () {
      expect(
        () => homeworkSessionFromJson(homeworkPayload()..[field] = null),
        throwsFormatException,
      );
    });
  }
  test('PRC-02: repository starts using start_homework', () async {
    final rpc = FakeRpc()..response = homeworkPayload();
    final repo = HomeworkRepositoryImpl(HomeworkRemoteDataSource(rpc.call));
    final result = await repo.start('t1') as Success<HomeworkSession>;
    expect(result.value, homeworkSession);
    expect(rpc.calls.single.$1, 'start_homework');
    expect(rpc.calls.single.$2, {'p_topic_id': 't1'});
  });
  test('PRC-05: saves shared RPC arguments and parses stale', () async {
    final rpc = FakeRpc()..response = {'ok': true, 'stale': true};
    final repo = HomeworkRepositoryImpl(HomeworkRemoteDataSource(rpc.call));
    final result =
        await repo.save(
              attemptId: 'hw1',
              questionId: 'q1',
              answer: 'B',
              timeMs: 100,
              marked: true,
              eliminated: ['A'],
              clientSeq: 10,
            )
            as Success<SaveOutcome>;
    expect(result.value, SaveOutcome.stale);
    expect(rpc.calls.single.$1, 'save_answer');
    expect(rpc.calls.single.$2, {
      'p_attempt_id': 'hw1',
      'p_question_id': 'q1',
      'p_answer': 'B',
      'p_time_ms': 100,
      'p_marked': true,
      'p_eliminated': ['A'],
      'p_client_seq': 10,
    });
  });
  test('PRC-02: submits homework report', () async {
    final rpc = FakeRpc()..response = homeworkReportPayload();
    final repo = HomeworkRepositoryImpl(HomeworkRemoteDataSource(rpc.call));
    final result = await repo.submit('hw1') as Success<HomeworkReport>;
    expect(result.value, homeworkReport);
    expect(rpc.calls.single.$1, 'submit_attempt');
    expect(rpc.calls.single.$2, {'p_attempt_id': 'hw1'});
  });
  test('PRC-02: maps malformed and server failures', () async {
    final rpc = FakeRpc()..response = {'attempt_id': 'bad'};
    final remote = HomeworkRemoteDataSource(rpc.call);
    expect(await remote.start('t1'), isA<Failure<HomeworkSession>>());
    rpc.error = const PostgrestException(message: 'homework_needed');
    expect(
      (await remote.start('t1') as Failure).error.code,
      ErrorCodes.homeworkNeeded,
    );
  });
}
