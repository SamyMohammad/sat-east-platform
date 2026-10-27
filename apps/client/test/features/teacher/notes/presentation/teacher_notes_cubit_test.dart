import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/notes/presentation/cubit/teacher_notes_cubit.dart';
import 'package:sat_east_client/features/teacher/notes/presentation/cubit/teacher_notes_state.dart';
import 'package:sat_east_client/features/teacher/questions/domain/services/file_picker_service.dart';

import '../../questions/import_fixtures.dart';
import '../notes_fixtures.dart';

void main() {
  late FakeTeacherNotesRepository repo;
  late FakePdfCounter counter;
  late TeacherNotesCubit cubit;
  setUp(() {
    repo = FakeTeacherNotesRepository();
    counter = FakePdfCounter();
    cubit = TeacherNotesCubit(actions(repo, counter: counter));
  });
  tearDown(() => cubit.close());
  test('C-3: load reads notes, limit and this topic subtopics', () async {
    await cubit.load('t1');
    final state = cubit.state as TeacherNotesReady;
    expect(state.data.notes, notes);
    expect(state.data.maxMb, 1);
    expect(state.data.subtopics.single.id, 's1');
  });
  test('C-3: load failure can retry', () async {
    repo.limitResult = const Failure(AppError('network'));
    await cubit.load('t1');
    expect(cubit.state, isA<TeacherNotesFailed>());
    repo.limitResult = const Success(1);
    await cubit.load('t1');
    expect(cubit.state, isA<TeacherNotesReady>());
  });
  for (final name in ['notes.txt', 'notes.pdf.exe']) {
    test('C-3: rejects $name before counting or writes', () async {
      await cubit.load('t1');
      repo.calls.clear();
      await cubit.upload(pdf(name: name));
      expect(repo.calls, isEmpty);
      expect(counter.calls, 0);
      expect(
        (cubit.state as TeacherNotesReady).error?.code,
        'notes_pdf_required',
      );
    });
  }
  test('C-3: server configured size limit rejects before writes', () async {
    await cubit.load('t1');
    repo.calls.clear();
    await cubit.upload(pdf(size: 1024 * 1024 + 1));
    expect(repo.calls, isEmpty);
    expect(counter.calls, 0);
    expect((cubit.state as TeacherNotesReady).error?.code, 'notes_too_large');
  });
  test('C-3: invalid PDF does not create an asset', () async {
    counter.result = const Failure(AppError('notes_invalid_pdf'));
    await cubit.load('t1');
    repo.calls.clear();
    await cubit.upload(pdf());
    expect(repo.calls, isEmpty);
    expect((cubit.state as TeacherNotesReady).error?.code, 'notes_invalid_pdf');
  });
  test(
    'C-3: upload counts then creates uploads confirms and reloads',
    () async {
      await cubit.load('t1');
      repo.calls.clear();
      await cubit.upload(pdf(name: 'Chapter.PDF'));
      expect(counter.calls, 1);
      expect(repo.calls, [
        'create:t1:Chapter:3',
        'upload:t1/new.pdf',
        'confirm:new',
        'list:t1',
      ]);
    },
  );
  for (final failure in ['create', 'upload', 'confirm']) {
    test(
      'C-3: $failure failure cleans up after create and reports one error',
      () async {
        repo.failures[failure] = const AppError('network');
        await cubit.load('t1');
        repo.calls.clear();
        await cubit.upload(pdf());
        if (failure == 'create') {
          expect(repo.calls, ['create:t1:notes:3']);
        } else {
          expect(repo.calls.sublist(repo.calls.length - 2), [
            'remove:t1/new.pdf',
            'delete:new',
          ]);
        }
        expect((cubit.state as TeacherNotesReady).error?.code, 'network');
      },
    );
  }
  test(
    'C-3: cleanup attempts row removal even if object removal fails',
    () async {
      repo.failures.addAll({
        'confirm': const AppError('network'),
        'remove': const AppError('network'),
      });
      await cubit.load('t1');
      repo.calls.clear();
      await cubit.upload(pdf());
      expect(repo.calls.last, 'delete:new');
      expect(
        (cubit.state as TeacherNotesReady).error?.code,
        'notes_cleanup_failed',
      );
    },
  );
  for (final op in ['rename', 'subtopic', 'reorder', 'delete']) {
    for (final fails in [false, true]) {
      test('C-3: $op ${fails ? 'failure' : 'success'} contract', () async {
        final method = switch (op) {
          'rename' || 'subtopic' => 'update',
          _ => op,
        };
        if (fails) repo.failures[method] = const AppError('forbidden');
        await cubit.load('t1');
        repo.calls.clear();
        switch (op) {
          case 'rename':
            await cubit.rename(notes.first, 'Renamed');
          case 'subtopic':
            await cubit.setSubtopic(notes.first, 's1');
          case 'reorder':
            await cubit.move('a2', -1);
          case 'delete':
            await cubit.delete(notes.first);
        }
        final expected = switch (op) {
          'rename' => ['update:a1:Renamed:null'],
          'subtopic' => ['update:a1:Algebra notes:s1'],
          'reorder' => ['reorder:t1:a2,a1'],
          _ => ['remove:t1/a1.pdf', 'delete:a1'],
        };
        expect(repo.calls, [...expected, if (!fails) 'list:t1']);
        expect(
          (cubit.state as TeacherNotesReady).error?.code,
          fails ? 'forbidden' : null,
        );
      });
    }
  }
  test('C-3: delete retains row when object removal fails', () async {
    repo.failures['remove'] = const AppError('network');
    await cubit.load('t1');
    repo.calls.clear();
    await cubit.delete(notes.first);
    expect(repo.calls, ['remove:t1/a1.pdf']);
  });
  test('C-3: upload is busy, ignores duplicate and closes safely', () async {
    final pending = Completer<Result<void>>();
    repo.pending = pending.future;
    await cubit.load('t1');
    final busy = cubit.stream.firstWhere(
      (s) => s is TeacherNotesReady && s.busy,
    );
    final saving = cubit.upload(pdf());
    await busy;
    await cubit.upload(pdf());
    expect((cubit.state as TeacherNotesReady).busy, isTrue);
    await cubit.close();
    pending.complete(const Success(null));
    await saving;
    expect(repo.calls.where((s) => s.startsWith('create:')), hasLength(1));
  });
  test('C-3: unknown subtopic sends no writes', () async {
    await cubit.load('t1');
    repo.calls.clear();
    await cubit.setSubtopic(notes.first, 'other-topic-subtopic');
    expect(repo.calls, isEmpty);
    expect((cubit.state as TeacherNotesReady).error?.code, 'invalid_input');
  });
  test('C-3: moving outside sibling boundaries is a no-op', () async {
    await cubit.load('t1');
    repo.calls.clear();
    await cubit.move('a1', -1);
    await cubit.move('a2', 1);
    await cubit.move('missing', 1);
    expect(repo.calls, isEmpty);
  });
  test('C-3: failed refresh preserves notes and reports error', () async {
    await cubit.load('t1');
    repo.listResult = const Failure(AppError('network'));
    await cubit.rename(notes.first, 'Changed');
    final state = cubit.state as TeacherNotesReady;
    expect(state.data.notes, notes);
    expect(state.error?.code, 'network');
    expect(state.busy, isFalse);
  });
  test('C-3: picking a PDF follows the upload workflow', () async {
    final picking = TeacherNotesCubit(actions(repo, picker: FakePdfPicker()));
    addTearDown(picking.close);
    await picking.load('t1');
    repo.calls.clear();
    await picking.pickAndUpload();
    expect(repo.calls, [
      'create:t1:notes:3',
      'upload:t1/new.pdf',
      'confirm:new',
      'list:t1',
    ]);
    expect((picking.state as TeacherNotesReady).busy, isFalse);
  });
  test('C-3: picker failure surfaces once without writes', () async {
    final picker = FakePdfPicker()
      ..result = const Failure(AppError('unsupported'));
    final picking = TeacherNotesCubit(actions(repo, picker: picker));
    addTearDown(picking.close);
    await picking.load('t1');
    repo.calls.clear();
    await picking.pickAndUpload();
    expect(repo.calls, isEmpty);
    expect((picking.state as TeacherNotesReady).error?.code, 'unsupported');
  });
  test('C-3: closing a pending picker prevents an upload', () async {
    final pending = Completer<Result<PickedPdf>>();
    final picker = FakePdfPicker()..pending = pending.future;
    final picking = TeacherNotesCubit(actions(repo, picker: picker));
    await picking.load('t1');
    repo.calls.clear();
    final pickingFile = picking.pickAndUpload();
    await picking.close();
    pending.complete(Success(pdf()));
    await pickingFile;
    expect(repo.calls, isEmpty);
  });
  test('C-3: cancelled picker keeps manager usable without errors', () async {
    final picker = FakeFilePicker();
    final picking = TeacherNotesCubit(actions(repo, picker: picker));
    addTearDown(picking.close);
    await picking.load('t1');
    repo.calls.clear();
    await picking.pickAndUpload();
    expect(repo.calls, isEmpty);
    expect((picking.state as TeacherNotesReady).error, isNull);
  });
}
