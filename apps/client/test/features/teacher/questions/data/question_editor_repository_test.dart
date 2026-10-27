import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/questions/data/datasources/question_editor_remote_data_source.dart';
import 'package:sat_east_client/features/teacher/questions/data/models/question_draft_model.dart';
import 'package:sat_east_client/features/teacher/questions/data/repositories/question_editor_repository_impl.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/question_save_result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/fakes/fake_rpc.dart';
import '../editor_fixtures.dart';

void main() {
  test('QB-06: draft round-trip includes all editable fields', () {
    expect(
      questionDraftToJson(questionDraftFromJson(editorJson)),
      equals(
        Map<String, Object?>.of(editorJson)
          ..remove('id')
          ..remove('version')
          ..remove('updated_at'),
      ),
    );
  });
  test('QB-06: SPR key and invalid numeric text are passed to the server', () {
    final draft = questionDraftFromJson({
      ...editorJson,
      'type': 'spr',
      'choices': <Object?>[],
      'key': {
        'accepted': ['7/2', '3.5'],
        'tolerance': 0.01,
      },
    });
    expect(questionDraftToJson(draft)['key'], {
      'accepted': ['7/2', '3.5'],
      'tolerance': 0.01,
    });
    expect(questionDraftToJson(draft.copyWith(tolerance: 'oops'))['key'], {
      'accepted': ['7/2', '3.5'],
      'tolerance': 'oops',
    });
  });
  test('QB-06: exact get and save RPC contracts', () async {
    final rpc = FakeRpc()..response = editorJson;
    final repo = QuestionEditorRepositoryImpl(
      QuestionEditorRemoteDataSource(rpc.call),
    );
    expect((await repo.get('q1') as Success).value, editorDraft);
    expect(rpc.calls.single.$1, 'teacher_get_question');
    expect(rpc.calls.single.$2, {'p_id': 'q1'});
    rpc.response = {'id': 'q1', 'version': 3};
    expect(await repo.save(editorDraft), isA<Success<QuestionSaveResult>>());
    expect(rpc.calls.last.$1, 'teacher_save_question');
    expect(rpc.calls.last.$2, {
      'p_id': 'q1',
      'p_expected_version': 2,
      'p_row': questionDraftToJson(editorDraft),
    });
  });
  test('QB-06: validation rejection is a successful typed result', () async {
    final rpc = FakeRpc()
      ..response = {
        'ok': false,
        'errors': [
          {
            'row': 1,
            'external_ref': 'EDIT_1',
            'field': 'key',
            'problem': 'spr_key',
          },
        ],
      };
    final repo = QuestionEditorRepositoryImpl(
      QuestionEditorRemoteDataSource(rpc.call),
    );
    final result = await repo.save(editorDraft) as Success<QuestionSaveResult>;
    expect(result.value, isA<QuestionRejected>());
    expect((result.value as QuestionRejected).errors.single.field, 'key');
  });
  for (final save in [false, true]) {
    for (final code in [
      'version_conflict',
      'forbidden',
      'invalid_input',
      'not_authenticated',
    ]) {
      test('QB-06: maps $code save=$save', () async {
        final rpc = FakeRpc()..error = PostgrestException(message: code);
        final repo = QuestionEditorRepositoryImpl(
          QuestionEditorRemoteDataSource(rpc.call),
        );
        expect(
          ((save ? await repo.save(editorDraft) : await repo.get('q1'))
                  as Failure)
              .error
              .code,
          code,
        );
      });
    }
    test('QB-06: transport error save=$save', () async {
      final rpc = FakeRpc()..error = const SocketException('offline');
      final repo = QuestionEditorRepositoryImpl(
        QuestionEditorRemoteDataSource(rpc.call),
      );
      expect(
        ((save ? await repo.save(editorDraft) : await repo.get('q1'))
                as Failure)
            .error
            .code,
        'network',
      );
    });
    test('QB-06: malformed response save=$save', () async {
      final rpc = FakeRpc();
      final repo = QuestionEditorRepositoryImpl(
        QuestionEditorRemoteDataSource(rpc.call),
      );
      expect(
        ((save ? await repo.save(editorDraft) : await repo.get('q1'))
                as Failure)
            .error
            .code,
        'internal',
      );
    });
  }
}
