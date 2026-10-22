import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/import_report.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/picked_file.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_import_cubit.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_import_state.dart';

import '../import_fixtures.dart';

void main() {
  late FakeImportRepository repo;
  late FakeFilePicker picker;
  late QuestionImportCubit cubit;
  setUp(() {
    repo = FakeImportRepository();
    picker = FakeFilePicker();
    cubit = QuestionImportCubit(repo, picker);
  });
  tearDown(() => cubit.close());
  test(
    'QB-05: pick parses only the array envelope then validates unchanged',
    () async {
      expect(cubit.state, isA<ImportIdle>());
      await cubit.pick();
      expect(cubit.state, isA<ImportReported>());
      expect(
        repo.dryCalls.single,
        equals([
          {
            'custom': [null, true, 3.5],
          },
          null,
        ]),
      );
      expect((cubit.state as ImportReported).file.name, 'bank.json');
      await cubit.validate();
      expect(repo.dryCalls.length, 2);
    },
  );
  for (final text in ['broken', '{}', 'null', '1']) {
    test('QB-05: invalid JSON array $text', () async {
      picker.result = Success(PickedFile(name: 'bad.json', text: text));
      await cubit.pick();
      expect((cubit.state as ImportFailed).error.code, 'invalid_input');
      expect(repo.dryCalls, isEmpty);
    });
  }
  for (final code in ['unsupported', 'network']) {
    test('QB-05: picker failure $code', () async {
      picker.result = Failure(AppError(code));
      await cubit.pick();
      expect((cubit.state as ImportFailed).error.code, code);
    });
  }
  test('QB-05: picker cancellation leaves idle', () async {
    picker.result = const Failure(AppError('cancelled'));
    await cubit.pick();
    expect(cubit.state, isA<ImportIdle>());
  });
  test('QB-05: report with errors cannot commit', () async {
    repo.dryResult = Success(badReport);
    await cubit.pick();
    await cubit.commit();
    expect(repo.commitCalls, isEmpty);
  });
  test('QB-05: clean report commits same parsed items', () async {
    await cubit.pick();
    await cubit.commit();
    expect(cubit.state, isA<ImportCommitted>());
    expect(repo.commitCalls.single, same(repo.dryCalls.single));
    await cubit.commit();
    expect(repo.commitCalls.length, 1);
  });
  test('QB-05: validation failure can retry', () async {
    repo.dryResult = const Failure(AppError('network'));
    await cubit.pick();
    expect(cubit.state, isA<ImportFailed>());
    repo.dryResult = Success(cleanReport);
    await cubit.validate();
    expect(cubit.state, isA<ImportReported>());
  });
  test('QB-05: commit error is propagated', () async {
    await cubit.pick();
    repo.commitResult = const Failure(AppError('invalid_input'));
    await cubit.commit();
    expect((cubit.state as ImportFailed).error.code, 'invalid_input');
  });
  test(
    'QB-05: reset clears file and prevents '
    'further validation or commit',
    () async {
      await cubit.pick();
      cubit.reset();
      await cubit.validate();
      await cubit.commit();
      expect(cubit.state, isA<ImportIdle>());
      expect(repo.dryCalls.length, 1);
      expect(repo.commitCalls, isEmpty);
    },
  );
  test(
    'QB-05: pending validation blocks duplicate actions '
    'and reset drops late result',
    () async {
      final pending = Completer<Result<ImportReport>>();
      repo.pending = pending.future;
      final pick = cubit.pick();
      await Future<void>.value();
      await cubit.validate();
      await cubit.commit();
      cubit.reset();
      pending.complete(Success(cleanReport));
      await pick;
      expect(cubit.state, isA<ImportIdle>());
    },
  );
  test('QB-05: close during reading ignores late result', () async {
    final pending = Completer<Result<PickedFile>>();
    picker.pending = pending.future;
    final pick = cubit.pick();
    await cubit.close();
    pending.complete(const Success(PickedFile(name: 'a', text: '[]')));
    await pick;
    expect(repo.dryCalls, isEmpty);
  });
}
