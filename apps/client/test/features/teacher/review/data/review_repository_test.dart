import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/review/data/datasources/review_remote_data_source.dart';
import 'package:sat_east_client/features/teacher/review/data/repositories/review_repository_impl.dart';
import 'package:sat_east_client/features/teacher/review/domain/entities/review.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../review_fixtures.dart';

void main() {
  test(
    'T-08: parses every teacher RPC shape and sends exact parameters',
    () async {
      final calls = <(String, Map<String, Object?>)>[];
      final repo = ReviewRepositoryImpl(
        ReviewRemoteDataSource((fn, params) async {
          calls.add((fn, params));
          return switch (fn) {
            'teacher_list_review_queue' => queueJson,
            'teacher_list_question_reports' => [
              {
                'report_id': 'r1',
                'reason': 'typo',
                'note': '<i>plain</i>',
                'created_at': '2026-10-29T10:00:00Z',
                'full_name': 'Student',
              },
            ],
            'teacher_resolve_reports' => {'closed': 2},
            _ => {'reported': 2, 'needs_review': 3},
          };
        }),
      );
      final page =
          (await repo.list(ReviewSection.needsReview, 2) as Success<ReviewPage>)
              .value;
      expect(page.rows.single.questionId, 'q1');
      expect(page.rows.single.reasons, {'answer_key': 1, 'typo': 1});
      expect(
        (await repo.reports('q1') as Success<List<QuestionReport>>)
            .value
            .single
            .fullName,
        'Student',
      );
      expect(
        (await repo.resolve('q1', 'fixed', 'Done') as Success<int>).value,
        2,
      );
      expect((await repo.counts() as Success<ReviewCounts>).value.total, 5);
      expect(calls.map((c) => c.$1), [
        'teacher_list_review_queue',
        'teacher_list_question_reports',
        'teacher_resolve_reports',
        'teacher_review_counts',
      ]);
      expect(calls.map((c) => c.$2), [
        {'p_section': 'needs_review', 'p_page': 2},
        {'p_question_id': 'q1'},
        {'p_question_id': 'q1', 'p_outcome': 'fixed', 'p_note': 'Done'},
        <String, Object?>{},
      ]);
    },
  );
  for (final code in ['forbidden', 'not_authenticated', 'invalid_input']) {
    test('T-08: $code mapped on all calls', () async {
      final repo = ReviewRepositoryImpl(
        ReviewRemoteDataSource(
          (_, _) async => throw PostgrestException(message: code),
        ),
      );
      expect(
        (await repo.list(ReviewSection.reported, 1) as Failure<ReviewPage>)
            .error
            .code,
        code,
      );
      expect(
        (await repo.reports('q1') as Failure<List<QuestionReport>>).error.code,
        code,
      );
      expect(
        (await repo.resolve('q1', 'fixed', null) as Failure<int>).error.code,
        code,
      );
      expect((await repo.counts() as Failure<ReviewCounts>).error.code, code);
    });
  }
  test('T-08: malformed and transport failures are typed', () async {
    final malformed = ReviewRepositoryImpl(
      ReviewRemoteDataSource((_, _) async => null),
    );
    expect(
      (await malformed.list(ReviewSection.reported, 1) as Failure<ReviewPage>)
          .error
          .code,
      'internal',
    );
    expect(
      (await malformed.reports('q1') as Failure<List<QuestionReport>>)
          .error
          .code,
      'internal',
    );
    expect(
      (await malformed.resolve('q1', 'fixed', null) as Failure<int>).error.code,
      'internal',
    );
    expect(
      (await malformed.counts() as Failure<ReviewCounts>).error.code,
      'internal',
    );
    final offline = ReviewRepositoryImpl(
      ReviewRemoteDataSource((_, _) async => throw TimeoutException('PRIVATE')),
    );
    expect(
      (await offline.counts() as Failure<ReviewCounts>).error.code,
      'network',
    );
  });
}
