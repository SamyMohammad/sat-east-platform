import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/import_report.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/question_draft.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/question_save_result.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_editor_cubit.dart';

import '../bank_fixtures.dart';
import '../editor_fixtures.dart';

void main() {
  late FakeEditorRepository repo;
  late FakeBankRepository bank;
  late QuestionEditorCubit cubit;
  setUp(() {
    repo = FakeEditorRepository();
    bank = FakeBankRepository();
    cubit = QuestionEditorCubit(repo, bank);
  });
  tearDown(() => cubit.close());
  test(
    'QB-06: new and existing load use shared topics and clean baselines',
    () async {
      await cubit.load();
      expect(repo.gets, isEmpty);
      expect(cubit.state.draft?.id, isNull);
      expect(cubit.state.isDirty, isFalse);
      expect(cubit.state.topics, bankTopics);
      await cubit.load('q1');
      expect(cubit.state.draft, editorDraft);
      expect(cubit.state.original, editorDraft);
    },
  );
  test('QB-06: metadata and get failures can reload', () async {
    bank.topicsResult = const Failure(AppError('network'));
    await cubit.load('q1');
    expect(cubit.state.error?.code, 'network');
    bank.topicsResult = Success(bankTopics);
    repo.getResult = const Failure(AppError('forbidden'));
    await cubit.load('q1');
    expect(cubit.state.error?.code, 'forbidden');
    repo.getResult = Success(editorDraft);
    await cubit.load('q1');
    expect(cubit.state.draft, editorDraft);
  });
  test(
    'QB-06: every edit group becomes dirty and discard restores all',
    () async {
      await cubit.load('q1');
      cubit
        ..editContent(
          stemMd: 'New',
          hintMd: 'Hint',
          explanationMd: 'Explain',
          images: ['img'],
        )
        ..editAnswer(type: 'spr', accepted: ['7/2'], tolerance: '0.01')
        ..editClassification(
          courseCodes: ['EST'],
          topicSlug: 'other',
          subtopicSlug: 'sub',
          skillCodes: ['GEO'],
          difficulty: 'H',
          pool: 'quiz',
          desmosFriendly: true,
          status: 'solved',
        )
        ..editSource(
          externalRef: 'NEW',
          source: 'book',
          sourcePage: '12',
          solvedBy: 'ai_double_agree',
        );
      expect(cubit.state.isDirty, isTrue);
      expect(cubit.state.draft?.stemMd, 'New');
      expect(cubit.state.draft?.type, 'spr');
      expect(cubit.state.draft?.courseCodes, ['EST']);
      expect(cubit.state.draft?.externalRef, 'NEW');
      cubit.discard();
      expect(cubit.state.draft, editorDraft);
      expect(cubit.state.isDirty, isFalse);
    },
  );
  test('QB-06: choice edits and key selection update answer data', () async {
    await cubit.load('q1');
    cubit
      ..editChoice('A', body: '3', misconception: 'Mistake')
      ..editAnswer(keyChoice: 'A');
    expect(cubit.state.draft?.choices.first.body, '3');
    expect(cubit.state.draft?.misconceptions['A'], 'Mistake');
    expect(cubit.state.draft?.keyChoice, 'A');
  });
  test('QB-06: primary course and topic changes clear descendants', () async {
    await cubit.load('q1');
    cubit.editClassification(courseCodes: ['SAT', 'EST']);
    expect(cubit.state.draft?.topicSlug, 'linear');
    cubit.editClassification(topicSlug: 'other');
    expect(cubit.state.draft?.subtopicSlug, '');
    cubit.editClassification(courseCodes: ['EST']);
    expect(cubit.state.draft?.topicSlug, '');
  });
  test(
    'QB-06: accepted save updates identity/version and clean baseline',
    () async {
      await cubit.load();
      cubit.editSource(externalRef: 'NEW');
      repo.saveResult = const Success(QuestionSaved(id: 'qnew', version: 1));
      await cubit.save();
      expect(repo.saves.single.externalRef, 'NEW');
      expect(cubit.state.draft?.id, 'qnew');
      expect(cubit.state.draft?.version, 1);
      expect(cubit.state.isDirty, isFalse);
      cubit
        ..editContent(stemMd: 'later')
        ..discard();
      expect(cubit.state.draft?.stemMd, '');
    },
  );
  test('QB-06: field rejections preserve edits and map each field', () async {
    await cubit.load('q1');
    cubit.editContent(stemMd: '');
    repo.saveResult = Success(
      QuestionRejected(const [
        ImportProblem(
          row: 1,
          externalRef: 'EDIT_1',
          field: 'stem_md',
          problem: 'missing:stem_md',
        ),
        ImportProblem(
          row: 1,
          externalRef: 'EDIT_1',
          field: 'key',
          problem: 'key_not_in_choices',
        ),
      ]),
    );
    await cubit.save();
    expect(cubit.state.serverErrors, {
      'stem_md': ['missing:stem_md'],
      'key': ['key_not_in_choices'],
    });
    expect(cubit.state.draft?.stemMd, '');
    cubit.editContent(stemMd: 'Fixed');
    expect(cubit.state.serverErrors.containsKey('stem_md'), isFalse);
    expect(cubit.state.serverErrors.containsKey('key'), isTrue);
  });
  test('QB-06: conflict blocks saves until explicit reload', () async {
    await cubit.load('q1');
    cubit.editContent(stemMd: 'Changed');
    repo.saveResult = const Failure(AppError('version_conflict'));
    await cubit.save();
    expect(cubit.state.conflict, isTrue);
    expect(cubit.state.isDirty, isTrue);
    await cubit.save();
    expect(repo.saves.length, 1);
    await cubit.load('q1');
    expect(cubit.state.conflict, isFalse);
    expect(cubit.state.draft, editorDraft);
  });
  test('QB-06: network error retains dirty edits for retry', () async {
    await cubit.load('q1');
    cubit.editSource(source: 'Other');
    repo.saveResult = const Failure(AppError('network'));
    await cubit.save();
    expect(cubit.state.error?.code, 'network');
    expect(cubit.state.isDirty, isTrue);
    repo.saveResult = const Success(QuestionSaved(id: 'q1', version: 3));
    await cubit.save();
    expect(cubit.state.isDirty, isFalse);
  });
  test('QB-06: clean and pending saves cannot duplicate or discard', () async {
    await cubit.load('q1');
    await cubit.save();
    expect(repo.saves, isEmpty);
    cubit.editContent(stemMd: 'Changed');
    final pending = Completer<Result<QuestionSaveResult>>();
    repo.pendingSave = pending.future;
    final saving = cubit.save();
    cubit
      ..editContent(stemMd: 'Ignored')
      ..discard();
    await cubit.save();
    expect(repo.saves.length, 1);
    expect(cubit.state.draft?.stemMd, 'Changed');
    pending.complete(const Success(QuestionSaved(id: 'q1', version: 3)));
    await saving;
  });
  test(
    'QB-06: stale get cannot overwrite new load and close ignores saves',
    () async {
      final pending = Completer<Result<QuestionDraft>>();
      repo.pendingGet = pending.future;
      final started = Completer<void>();
      repo.onGet = started.complete;
      final old = cubit.load('q1');
      await started.future;
      repo.pendingGet = null;
      await cubit.load();
      pending.complete(Success(editorDraft));
      await old;
      expect(cubit.state.draft?.id, isNull);
      cubit.editSource(externalRef: 'NEW');
      final saving = Completer<Result<QuestionSaveResult>>();
      repo.pendingSave = saving.future;
      final save = cubit.save();
      await cubit.close();
      saving.complete(const Success(QuestionSaved(id: 'qnew', version: 1)));
      await expectLater(save, completes);
    },
  );
}
