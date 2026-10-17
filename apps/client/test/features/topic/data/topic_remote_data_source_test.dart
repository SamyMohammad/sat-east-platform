import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/topic/data/datasources/topic_remote_data_source.dart';
import 'package:sat_east_client/features/topic/data/repositories/topic_repository_impl.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_detail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/fakes/fake_rpc.dart';
import '../topic_fixture.dart';

void main() {
  late FakeRpc rpc;
  late TopicRemoteDataSource source;
  setUp(() {
    rpc = FakeRpc()..response = topicPayload();
    source = TopicRemoteDataSource(rpc.call);
  });

  test('PRC-03: repository forwards topic id to get_topic RPC', () async {
    final result = await TopicRepositoryImpl(source).getTopic('topic-1');
    expect(rpc.calls.single.$1, 'get_topic');
    expect(rpc.calls.single.$2, {'p_topic_id': 'topic-1'});
    expect((result as Success<TopicDetail>).value.id, 't1');
  });

  for (final code in [
    ErrorCodes.topicLocked,
    ErrorCodes.accessExpired,
    ErrorCodes.notEnrolled,
    ErrorCodes.invalidInput,
    ErrorCodes.practiceNeeded,
    ErrorCodes.cooldownActive,
    ErrorCodes.deadlinePassed,
  ]) {
    test('PRC-03: repository preserves server error $code', () async {
      rpc.error = PostgrestException(message: code);
      final result = await TopicRepositoryImpl(source).getTopic('t1');
      expect((result as Failure).error.code, code);
    });
  }

  test('PRC-03: maps transport error to network', () async {
    rpc.error = const SocketException('offline');
    expect(
      (await source.getTopic('t1') as Failure).error.code,
      ErrorCodes.network,
    );
  });

  test('PRC-03: malformed server response becomes internal failure', () async {
    rpc.response = {'id': 't1'};
    expect(
      (await source.getTopic('t1') as Failure).error.code,
      ErrorCodes.internal,
    );
  });
}
