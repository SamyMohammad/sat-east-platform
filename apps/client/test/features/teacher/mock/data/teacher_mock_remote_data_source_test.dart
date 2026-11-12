import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/mock/data/datasources/teacher_mock_remote_data_source.dart';
import 'package:sat_east_client/features/teacher/mock/data/repositories/teacher_mock_repository_impl.dart';
import 'package:sat_east_client/features/teacher/mock/domain/entities/mock_entities.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/fakes/fake_rpc.dart';
import '../mock_fixtures.dart';

const _course = 'course-1';

TeacherMockRepositoryImpl _repo(FakeRpc rpc) =>
    TeacherMockRepositoryImpl(TeacherMockRemoteDataSource(rpc.call));

T _ok<T>(Result<T> r) => (r as Success<T>).value;

void main() {
  test('MCK-03: overview parses 19 cells summing to 66', () async {
    final rpc = FakeRpc()..response = overviewJson();
    final o = _ok(await _repo(rpc).overview(_course));
    expect(rpc.calls.single.$1, 'teacher_mock_overview');
    expect(rpc.calls.single.$2, equals({'p_course_id': _course}));
    expect(o.templateName, 'SAT Math');
    expect(o.needPerForm, hasLength(19));
    expect(o.needPerForm.fold<int>(0, (s, c) => s + c.count), 66);
    expect(o.forms, hasLength(2));
    expect(o.forms[0].status, MockFormStatus.published);
    expect(o.forms[0].publishedAt, DateTime.parse('2026-11-10T09:30:00+00:00'));
    expect(o.forms[1].status, MockFormStatus.draft);
    expect(o.forms[1].publishedAt, isNull);
    expect(o.canAssemble, isTrue);
    expect(o.noDomain, 0);
  });

  test('MCK-03: overview with shortage cannot assemble', () async {
    final rpc = FakeRpc()
      ..response = overviewJson(missing: [shortageCellJson()], noDomain: 3);
    final o = _ok(await _repo(rpc).overview(_course));
    expect(o.canAssemble, isFalse);
    expect(o.missing, [parsedShortage]);
    expect(o.noDomain, 3);
  });

  test('MCK-03: assemble success returns Assembled', () async {
    final rpc = FakeRpc()..response = {'ok': true, 'set_no': 2, 'form_no': 1};
    final r = _ok(await _repo(rpc).assemble(_course, 2));
    expect(rpc.calls.single.$1, 'teacher_assemble_mock_form');
    expect(
      rpc.calls.single.$2,
      equals({'p_course_id': _course, 'p_set_no': 2}),
    );
    expect(r, const Assembled(setNo: 2, formNo: 1));
  });

  test('MCK-03: assemble shortage returns Shortage', () async {
    final rpc = FakeRpc()
      ..response = {
        'ok': false,
        'missing': [shortageCellJson()],
        'no_domain': 5,
      };
    final r = _ok(await _repo(rpc).assemble(_course, 1));
    expect(r, const Shortage(missing: [parsedShortage], noDomain: 5));
  });

  test('MCK-03: form parses 3 modules x 22 slots', () async {
    final rpc = FakeRpc()..response = formJson();
    final f = _ok(await _repo(rpc).form(_course, 1, 2));
    expect(rpc.calls.single.$1, 'teacher_get_mock_form');
    expect(
      rpc.calls.single.$2,
      equals({'p_course_id': _course, 'p_set_no': 1, 'p_form_no': 2}),
    );
    expect(f.status, MockFormStatus.draft);
    expect(f.modules.map((m) => m.name), ['M1', 'M2E', 'M2H']);
    expect(f.modules.every((m) => m.slots.length == 22), isTrue);
    final first = f.modules.first.slots.first;
    expect(first.slotNo, 1);
    expect(first.questionId, 'M1-q1');
    expect(first.externalRef, 'REF-M1-1');
    expect(f.modules.first.slots[1].externalRef, isNull);
    expect(first.stemMd, 'Stem M1 1');
  });

  test('MCK-03: a slot with a null domain still parses', () async {
    final json = formJson();
    final modules = json['modules']! as List<Object?>;
    final questions =
        (modules.first! as Map<String, Object?>)['questions']! as List<Object?>;
    (questions.first! as Map<String, Object?>)['domain'] = null;
    final rpc = FakeRpc()..response = json;
    final f = _ok(await _repo(rpc).form(_course, 1, 2));
    expect(f.modules.first.slots.first.domain, isNull);
    expect(f.modules.first.slots[1].domain, 'algebra');
  });

  test('MCK-03: published form carries publishedAt', () async {
    final rpc = FakeRpc()..response = formJson(status: 'published');
    final f = _ok(await _repo(rpc).form(_course, 1, 2));
    expect(f.status, MockFormStatus.published);
    expect(f.publishedAt, isNotNull);
  });

  test('MCK-03: candidates sends the question id', () async {
    final rpc = FakeRpc()..response = candidatesJson();
    final c = _ok(await _repo(rpc).candidates(_course, 1, 2, 'M1-q1'));
    expect(rpc.calls.single.$1, 'teacher_mock_swap_candidates');
    expect(
      rpc.calls.single.$2,
      equals({
        'p_course_id': _course,
        'p_set_no': 1,
        'p_form_no': 2,
        'p_question_id': 'M1-q1',
      }),
    );
    expect(c, hasLength(2));
    expect(c[1].externalRef, isNull);
    expect(c[0].stemMd, 'Candidate one');
  });

  test('MCK-03: swap sends old and new ids', () async {
    final rpc = FakeRpc()..response = {'ok': true};
    final r = await _repo(rpc).swap(_course, 1, 2, 'old', 'new');
    expect(r, isA<Success<void>>());
    expect(rpc.calls.single.$1, 'teacher_swap_mock_question');
    expect(
      rpc.calls.single.$2,
      equals({
        'p_course_id': _course,
        'p_set_no': 1,
        'p_form_no': 2,
        'p_old_id': 'old',
        'p_new_id': 'new',
      }),
    );
  });

  test('MCK-03: deleteDraft calls the RPC', () async {
    final rpc = FakeRpc()..response = {'ok': true};
    final r = await _repo(rpc).deleteDraft(_course, 1, 2);
    expect(r, isA<Success<void>>());
    expect(rpc.calls.single.$1, 'teacher_delete_mock_draft');
    expect(
      rpc.calls.single.$2,
      equals({'p_course_id': _course, 'p_set_no': 1, 'p_form_no': 2}),
    );
  });

  test('MCK-03: publish ok returns Published', () async {
    final rpc = FakeRpc()..response = {'ok': true};
    final r = _ok(await _repo(rpc).publish(_course, 1, 2));
    expect(rpc.calls.single.$1, 'teacher_publish_mock_form');
    expect(r, const Published());
  });

  test('MCK-03: publish stale returns Stale with ids in order', () async {
    final rpc = FakeRpc()
      ..response = {
        'ok': false,
        'stale': ['b', 'a'],
      };
    final r = _ok(await _repo(rpc).publish(_course, 1, 2));
    expect(r, const Stale(['b', 'a']));
  });

  group('MCK-03: malformed payloads become internal', () {
    final cases = <String, Future<Result<Object?>> Function(FakeRpc)>{
      'overview': (rpc) => _repo(rpc).overview(_course),
      'assemble': (rpc) => _repo(rpc).assemble(_course, 1),
      'form': (rpc) => _repo(rpc).form(_course, 1, 1),
      'candidates': (rpc) => _repo(rpc).candidates(_course, 1, 1, 'q'),
      'swap': (rpc) => _repo(rpc).swap(_course, 1, 1, 'a', 'b'),
      'deleteDraft': (rpc) => _repo(rpc).deleteDraft(_course, 1, 1),
      'publish': (rpc) => _repo(rpc).publish(_course, 1, 1),
    };
    for (final MapEntry(key: name, value: call) in cases.entries) {
      test(name, () async {
        final rpc = FakeRpc()..response = 'nope';
        final r = await call(rpc);
        expect((r as Failure).error.code, ErrorCodes.internal);
      });
    }
    test('overview with a non-array need_per_form', () async {
      final rpc = FakeRpc()
        ..response = {...overviewJson(), 'need_per_form': 'x'};
      final r = await _repo(rpc).overview(_course);
      expect((r as Failure).error.code, ErrorCodes.internal);
    });
    test('assemble ok:false without a missing list', () async {
      final rpc = FakeRpc()..response = {'ok': false};
      final r = await _repo(rpc).assemble(_course, 1);
      expect((r as Failure).error.code, ErrorCodes.internal);
    });
  });

  group('MCK-03: server errors', () {
    for (final code in ['forbidden', 'invalid_input', 'mock_form_published']) {
      test('maps $code on publish and form', () async {
        final rpc = FakeRpc()..error = PostgrestException(message: code);
        expect(
          ((await _repo(rpc).publish(_course, 1, 1)) as Failure).error.code,
          code,
        );
        expect(
          ((await _repo(rpc).form(_course, 1, 1)) as Failure).error.code,
          code,
        );
      });
    }
  });
}
