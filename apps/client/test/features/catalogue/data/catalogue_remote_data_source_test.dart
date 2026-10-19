import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/catalogue/data/datasources/catalogue_remote_data_source.dart';
import 'package:sat_east_client/features/catalogue/domain/entities/catalogue_course.dart';
import 'package:sat_east_client/features/catalogue/domain/entities/course_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/fakes/fake_rpc.dart';
import '../catalogue_fixtures.dart';

void main() {
  late FakeRpc rpc;
  late CatalogueRemoteDataSource source;
  setUp(() {
    rpc = FakeRpc();
    source = CatalogueRemoteDataSource(rpc.call);
  });
  test('PAY-01: catalogue sends null country and parses rows', () async {
    rpc.response = [coursePayload];
    final result = await source.getCatalogue();
    expect(
      (result as Success<List<CatalogueCourse>>).value.single.slug,
      'sat-math',
    );
    expect(rpc.calls.single.$1, 'get_catalogue');
    expect(rpc.calls.single.$2, {'p_country': null});
  });
  test(
    'PAY-01: page sends slug and null country and parses syllabus',
    () async {
      rpc.response = pagePayload;
      final result = await source.getCoursePage('sat-math');
      expect((result as Success<CoursePage>).value.units, hasLength(2));
      expect(rpc.calls.single.$1, 'get_course_page');
      expect(rpc.calls.single.$2, {
        'p_slug': 'sat-math',
        'p_country': null,
      });
    },
  );
  for (final page in [false, true]) {
    Future<Result<Object>> fetch() async =>
        page ? source.getCoursePage('missing') : source.getCatalogue();
    test('PAY-01: $page invalid_input uses shared mapper', () async {
      rpc.error = const PostgrestException(message: 'invalid_input');
      expect(
        (await fetch() as Failure).error,
        const AppError(ErrorCodes.invalidInput, 'invalid_input'),
      );
    });
    test('PAY-01: $page transport maps to network', () async {
      rpc.error = const SocketException('offline');
      expect((await fetch() as Failure).error.code, ErrorCodes.network);
    });
    test('PAY-01: $page unexpected error maps to internal', () async {
      rpc.error = StateError('private details');
      expect((await fetch() as Failure).error.code, ErrorCodes.internal);
    });
    for (final payload in <Object?>[null, 1, {}, 'bad']) {
      test('PAY-01: $page malformed $payload maps to internal', () async {
        rpc.response = payload;
        expect((await fetch() as Failure).error.code, ErrorCodes.internal);
      });
    }
  }
  for (final payload in <Object?>[
    {...pagePayload, 'units': null},
    {
      ...pagePayload,
      'units': [
        {'title': 'Algebra', 'topics': null},
      ],
    },
    {
      ...pagePayload,
      'units': [
        {
          'title': 'Algebra',
          'topics': [
            {
              'slug': 'linear',
              'title': 'Linear equations',
              'is_free_preview': 'true',
              'subtopic_count': 4,
            },
          ],
        },
      ],
    },
  ]) {
    test('PAY-01: malformed syllabus becomes internal failure', () async {
      rpc.response = payload;
      expect(
        (await source.getCoursePage('sat-math') as Failure).error.code,
        ErrorCodes.internal,
      );
    });
  }
  test('PAY-01: empty catalogue succeeds', () async {
    rpc.response = <Object?>[];
    expect((await source.getCatalogue() as Success).value, isEmpty);
  });
}
