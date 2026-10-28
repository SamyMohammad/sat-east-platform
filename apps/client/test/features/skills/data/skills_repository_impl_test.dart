import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/skills/data/datasources/skills_remote_data_source.dart';
import 'package:sat_east_client/features/skills/data/repositories/skills_repository_impl.dart';
import 'package:sat_east_client/features/skills/domain/entities/skills_overview.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/fakes/fake_rpc.dart';
import '../skills_fixtures.dart';

void main() {
  late FakeRpc rpc;
  late SkillsRepositoryImpl repository;

  setUp(() {
    rpc = FakeRpc()..response = skillsPayload;
    repository = SkillsRepositoryImpl(
      SkillsRemoteDataSource(rpc.call),
    );
  });

  group('ANL-01: SkillsRepositoryImpl', () {
    test('ANL-01: trend_min_answers_from_payload', () async {
      rpc.response = skillsPayloadWith({
        'summary': {
          'solved': 12,
          'total': 40,
          'graded_answers': 31,
          'trend_min_answers': 17,
        },
      });
      final result = await repository.load('c1');
      expect(
        (result as Success<SkillsOverview>).value.summary.trendMinAnswers,
        17,
      );
      expect(rpc.calls, hasLength(1));
    });

    test('ANL-01: missing_trend_min_answers_returns_internal', () async {
      rpc.response = skillsPayloadWith({
        'summary': {'solved': 12, 'total': 40, 'graded_answers': 31},
      });
      expect(
        (await repository.load('c1') as Failure).error.code,
        ErrorCodes.internal,
      );
    });

    for (final value in <Object?>[null, 'ten', 0, -1, 1.5]) {
      test(
        'ANL-01: invalid_trend_min_answers $value returns internal',
        () async {
          rpc.response = skillsPayloadWith({
            'summary': {
              'solved': 12,
              'total': 40,
              'graded_answers': 31,
              'trend_min_answers': value,
            },
          });
          expect(
            (await repository.load('c1') as Failure).error.code,
            ErrorCodes.internal,
          );
        },
      );
    }

    test('ANL-01: calls get_my_skills with the course id', () async {
      final result = await repository.load('c1');

      expect(rpc.calls.single.$1, 'get_my_skills');
      expect(rpc.calls.single.$2, {'p_course_id': 'c1'});
      expect((result as Success<SkillsOverview>).value.summary.solved, 12);
    });

    test('ANL-01: maps_access_expired', () async {
      rpc.error = const PostgrestException(message: 'access_expired');

      final result = await repository.load('c1');

      expect((result as Failure).error.code, ErrorCodes.accessExpired);
    });

    test('ANL-01: maps_not_enrolled', () async {
      rpc.error = const PostgrestException(message: 'not_enrolled');

      final result = await repository.load('c1');

      expect((result as Failure).error.code, ErrorCodes.notEnrolled);
    });

    test('ANL-01: maps_unknown_to_internal', () async {
      rpc.error = const PostgrestException(message: 'boom');

      final result = await repository.load('c1');

      expect((result as Failure).error.code, ErrorCodes.internal);
    });

    test('ANL-01: malformed payload gives internal Failure', () async {
      rpc.response = {'summary': 1};

      final result = await repository.load('c1');

      expect((result as Failure).error.code, ErrorCodes.internal);
    });

    test('ANL-01: non-map payload gives internal Failure', () async {
      rpc.response = <Object?>[];

      final result = await repository.load('c1');

      expect((result as Failure).error.code, ErrorCodes.internal);
    });

    test('ANL-01: SocketException gives network Failure', () async {
      rpc.error = const SocketException('down');

      final result = await repository.load('c1');

      expect((result as Failure).error.code, ErrorCodes.network);
    });
  });
}
