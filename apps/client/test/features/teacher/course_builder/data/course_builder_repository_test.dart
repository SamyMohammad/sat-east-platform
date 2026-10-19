import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/course_builder/data/datasources/course_builder_remote_data_source.dart';
import 'package:sat_east_client/features/teacher/course_builder/data/repositories/course_builder_repository_impl.dart';
import 'package:sat_east_client/features/teacher/course_builder/domain/entities/node_kind.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/fakes/fake_rpc.dart';
import '../builder_fixtures.dart';

void main() {
  late FakeRpc rpc;
  late CourseBuilderRepositoryImpl repo;
  setUp(() {
    rpc = FakeRpc();
    repo = CourseBuilderRepositoryImpl(CourseBuilderRemoteDataSource(rpc.call));
  });
  test('C-1: list and tree use teacher reads and parse responses', () async {
    rpc.response = coursesJson;
    expect((await repo.listCourses() as Success).value, builderCourses);
    expect(rpc.calls.last.$1, 'teacher_list_courses');
    expect(rpc.calls.last.$2, isEmpty);
    rpc.response = treeJson;
    expect((await repo.getTree('c1') as Success).value, builderTree);
    expect(rpc.calls.last.$1, 'teacher_get_course_tree');
    expect(rpc.calls.last.$2, equals({'p_course_id': 'c1'}));
  });
  final writes =
      <String, Future<Result<dynamic>> Function(CourseBuilderRepositoryImpl)>{
        'unit': (r) => r.upsertUnit(courseId: 'c1', title: 'Unit'),
        'topic': (r) => r.upsertTopic(id: 't1', unitId: 'u1', title: 'Topic'),
        'subtopic': (r) => r.upsertSubtopic(topicId: 't1', title: 'Subtopic'),
        'reorder': (r) => r.reorder(NodeKind.topic, 'u1', ['t2', 't1']),
        'delete': (r) => r.delete(NodeKind.subtopic, 's1'),
        'flags': (r) => r.setFlags('t1', isPublished: true),
      };
  final params = <String, Map<String, Object?>>{
    'unit': {'p_id': null, 'p_course_id': 'c1', 'p_title': 'Unit'},
    'topic': {'p_id': 't1', 'p_unit_id': 'u1', 'p_title': 'Topic'},
    'subtopic': {'p_id': null, 'p_topic_id': 't1', 'p_title': 'Subtopic'},
    'reorder': {
      'p_kind': 'topic',
      'p_parent_id': 'u1',
      'p_ids': ['t2', 't1'],
    },
    'delete': {'p_kind': 'subtopic', 'p_id': 's1'},
    'flags': {'p_id': 't1', 'p_is_published': true, 'p_is_free_preview': null},
  };
  for (final entry in writes.entries) {
    test('C-1: ${entry.key} sends exact RPC contract', () async {
      rpc.response = switch (entry.key) {
        'reorder' || 'delete' => {'ok': true},
        'flags' => {'is_published': true, 'is_free_preview': false},
        _ => {'id': 'new-id'},
      };
      final result = await entry.value(repo);
      expect(result, isA<Success<dynamic>>());
      final fn = switch (entry.key) {
        'delete' => 'teacher_delete_node',
        'flags' => 'teacher_set_topic_flags',
        'reorder' => 'teacher_reorder',
        _ => 'teacher_upsert_${entry.key}',
      };
      expect(rpc.calls.single.$1, fn);
      expect(rpc.calls.single.$2, equals(params[entry.key]));
    });
  }
  final operations = {
    ...writes,
    'list': (CourseBuilderRepositoryImpl r) => r.listCourses(),
    'tree': (CourseBuilderRepositoryImpl r) => r.getTree('c1'),
  };
  for (final operation in operations.entries) {
    for (final code in [
      ErrorCodes.inUse,
      ErrorCodes.forbidden,
      ErrorCodes.invalidInput,
      ErrorCodes.notAuthenticated,
      ErrorCodes.rateLimited,
    ]) {
      test('ADM-01: ${operation.key} preserves $code', () async {
        rpc.error = PostgrestException(message: code);
        expect((await operation.value(repo) as Failure).error.code, code);
      });
    }
    test('C-1: ${operation.key} maps network failure', () async {
      rpc.error = const SocketException('offline');
      expect(
        (await operation.value(repo) as Failure).error.code,
        ErrorCodes.network,
      );
    });
    test('C-1: ${operation.key} rejects malformed payload', () async {
      rpc.response = {'unexpected': true};
      expect(
        (await operation.value(repo) as Failure).error.code,
        ErrorCodes.internal,
      );
    });
  }
}
