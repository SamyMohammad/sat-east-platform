import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/course_map/data/datasources/course_map_remote_data_source.dart';
import 'package:sat_east_client/features/course_map/domain/entities/course_map.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/fakes/fake_rpc.dart';

const Map<String, Object?> _payload = {
  'course': {'id': 'c1', 'slug': 'sat-math', 'title': 'SAT Math'},
  'continue': null,
  'units': <Object?>[],
};

void main() {
  late FakeRpc rpc;
  late CourseMapRemoteDataSource source;

  setUp(() {
    rpc = FakeRpc()..response = _payload;
    source = CourseMapRemoteDataSource(rpc.call);
  });

  group('L-1: CourseMapRemoteDataSource', () {
    test('L-1: passes empty params for a null slug', () async {
      final result = await source.getCourseMap();

      expect(rpc.calls.single.$1, 'get_course_map');
      expect(rpc.calls.single.$2, isEmpty);
      expect((result as Success<CourseMap>).value.slug, 'sat-math');
    });

    test('L-1: passes p_slug when a slug is given', () async {
      await source.getCourseMap(slug: 'x');

      expect(rpc.calls.single.$1, 'get_course_map');
      expect(rpc.calls.single.$2, {'p_slug': 'x'});
    });

    test('L-1: maps not_enrolled to a Failure', () async {
      rpc.error = const PostgrestException(message: 'not_enrolled');

      final result = await source.getCourseMap();

      expect((result as Failure).error.code, ErrorCodes.notEnrolled);
    });

    test('L-1: malformed payload gives internal Failure', () async {
      rpc.response = {'units': 1};

      final result = await source.getCourseMap();

      expect((result as Failure).error.code, ErrorCodes.internal);
    });

    test('L-1: SocketException gives network Failure', () async {
      rpc.error = const SocketException('down');

      final result = await source.getCourseMap();

      expect((result as Failure).error.code, ErrorCodes.network);
    });
  });
}
