import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/mock/data/models/mock_models.dart';
import 'package:sat_east_client/features/teacher/mock/domain/entities/mock_entities.dart';
import 'package:sat_east_client/features/teacher/mock/domain/usecases/find_sat_course.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/cubit/mock_form_cubit.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/cubit/mock_form_state.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/mock_copy.dart';

import '../../course_builder/builder_fixtures.dart';
import '../../questions/editor_fixtures.dart';
import '../mock_fakes.dart';
import '../mock_fixtures.dart';

MockForm _formReplacing(String oldId, String newId) {
  final json = formJson();
  for (final module in json['modules']! as List<Object?>) {
    final questions =
        (module! as Map<String, Object?>)['questions']! as List<Object?>;
    for (final q in questions) {
      final map = q! as Map<String, Object?>;
      if (map['id'] == oldId) map['id'] = newId;
    }
  }
  return mockFormFromJson(json);
}

class _Setup {
  _Setup() {
    cubit = MockFormCubit(
      mock,
      editor,
      FindSatCourse(courses),
      setNo: 1,
      formNo: 2,
    );
  }
  final mock = FakeTeacherMockRepository();
  final editor = FakeEditorRepository();
  final courses = FakeBuilderRepository();
  late final MockFormCubit cubit;
  MockFormLoaded get loaded => cubit.state as MockFormLoaded;
}

void main() {
  test('MCK-03: load fetches the SAT course form with 3 modules', () async {
    final t = _Setup();
    await t.cubit.load();
    expect(t.loaded.form.modules, hasLength(3));
    expect(t.mock.calls.single.$2, ['c1', 1, 2]);
    expect(t.loaded.stale, isEmpty);
  });

  test('MCK-03: no SAT course gives Missing and no mock RPC', () async {
    final t = _Setup();
    t.courses.courses = Success(
      builderCourses.where((c) => c.code != 'SAT').toList(),
    );
    await t.cubit.load();
    expect(t.cubit.state, isA<MockFormMissing>());
    expect(t.mock.calls, isEmpty);
  });

  test('MCK-03: invalid_input on load gives Missing', () async {
    final t = _Setup();
    t.mock.formResult = const Failure(AppError('invalid_input'));
    await t.cubit.load();
    expect(t.cubit.state, isA<MockFormMissing>());
  });

  test('MCK-03: other load failures give Failed, retry recovers', () async {
    final t = _Setup();
    t.mock.formResult = const Failure(AppError('network'));
    await t.cubit.load();
    expect((t.cubit.state as MockFormFailed).error.code, 'network');
    t.mock.formResult = Success(draftForm);
    await t.cubit.load();
    expect(t.cubit.state, isA<MockFormLoaded>());
  });

  test('MCK-03: preview loads the draft for the tapped id', () async {
    final t = _Setup();
    await t.cubit.load();
    await t.cubit.openPreview('M1-q1');
    expect(t.editor.gets, ['M1-q1']);
    expect(t.loaded.previewId, 'M1-q1');
    expect(t.loaded.preview, editorDraft);
    expect(t.loaded.previewError, isNull);
  });

  test('MCK-03: preview failure keeps the id and sets previewError', () async {
    final t = _Setup();
    await t.cubit.load();
    t.editor.getResult = const Failure(AppError('forbidden'));
    await t.cubit.openPreview('M1-q1');
    expect(t.loaded.previewId, 'M1-q1');
    expect(t.loaded.preview, isNull);
    expect(t.loaded.previewError?.code, 'forbidden');
    t.cubit.closePreview();
    expect(t.loaded.previewId, isNull);
    expect(t.loaded.previewError, isNull);
  });

  test('MCK-03: openSwap loads the slot candidates', () async {
    final t = _Setup();
    await t.cubit.load();
    await t.cubit.openSwap('M1-q3');
    expect(t.loaded.swappingId, 'M1-q3');
    expect(t.loaded.candidates, candidateList);
    expect(t.mock.calls.last.$2, ['c1', 1, 2, 'M1-q3']);
  });

  test(
    'MCK-03: candidate failure closes the swap and sets lastError',
    () async {
      final t = _Setup();
      await t.cubit.load();
      t.mock.candidatesResult = const Failure(AppError('network'));
      await t.cubit.openSwap('M1-q3');
      expect(t.loaded.swappingId, isNull);
      expect(t.loaded.lastError?.code, 'network');
    },
  );

  test('MCK-03: swap calls swap then reloads and drops the stale id', () async {
    final t = _Setup();
    await t.cubit.load();
    t.mock.publishResult = const Success(Stale(['M1-q3', 'M2E-q5']));
    await t.cubit.publish();
    expect(t.loaded.stale, {'M1-q3', 'M2E-q5'});
    await t.cubit.openSwap('M1-q3');
    final before = t.mock.count('form');
    final ok = await t.cubit.swap('c1');
    expect(ok, isTrue);
    expect(t.mock.calls.where((c) => c.$1 == 'swap').single.$2, [
      'c1',
      1,
      2,
      'M1-q3',
      'c1',
    ]);
    expect(t.mock.count('form'), before + 1);
    expect(t.loaded.stale, {'M2E-q5'});
    expect(t.loaded.swappingId, isNull);
    expect(t.loaded.candidates, isNull);
    expect(t.loaded.busy, isFalse);
  });

  test('MCK-03: publish Published reloads the form as published', () async {
    final t = _Setup();
    await t.cubit.load();
    t.mock.formResult = Success(publishedForm);
    await t.cubit.publish();
    expect(t.loaded.form.status, MockFormStatus.published);
    expect(t.loaded.stale, isEmpty);
    expect(t.loaded.busy, isFalse);
  });

  test('MCK-03: publish Stale marks the ids and stays draft', () async {
    final t = _Setup();
    await t.cubit.load();
    t.mock.publishResult = const Success(Stale(['M1-q1']));
    await t.cubit.publish();
    expect(t.loaded.stale, {'M1-q1'});
    expect(t.loaded.form.status, MockFormStatus.draft);
    expect(t.mock.count('form'), 1);
  });

  test('MCK-03: publish after swapping the stale ones succeeds', () async {
    final t = _Setup();
    await t.cubit.load();
    t.mock.publishResult = const Success(Stale(['M1-q1']));
    await t.cubit.publish();
    await t.cubit.openSwap('M1-q1');
    await t.cubit.swap('c1');
    expect(t.loaded.stale, isEmpty);
    t.mock.publishResult = const Success(Published());
    t.mock.formResult = Success(publishedForm);
    await t.cubit.publish();
    expect(t.loaded.form.status, MockFormStatus.published);
  });

  for (final action in ['swap', 'publish', 'delete']) {
    test(
      'MCK-03: mock_form_published on $action sets lastError and reloads',
      () async {
        final t = _Setup();
        await t.cubit.load();
        const published = Failure<void>(AppError('mock_form_published'));
        t.mock.formResult = Success(publishedForm);
        switch (action) {
          case 'swap':
            await t.cubit.openSwap('M1-q1');
            t.mock.swapResult = published;
            expect(await t.cubit.swap('c1'), isFalse);
          case 'publish':
            t.mock.publishResult = const Failure(
              AppError('mock_form_published'),
            );
            await t.cubit.publish();
          case 'delete':
            t.mock.deleteResult = published;
            expect(await t.cubit.delete(), isFalse);
        }
        expect(t.loaded.lastError?.code, 'mock_form_published');
        expect(t.loaded.form.status, MockFormStatus.published);
        expect(t.loaded.busy, isFalse);
        expect(t.loaded.swappingId, isNull);
      },
    );
  }

  test('MCK-03: other swap failure keeps the sheet open', () async {
    final t = _Setup();
    await t.cubit.load();
    await t.cubit.openSwap('M1-q1');
    t.mock.swapResult = const Failure(AppError('network'));
    expect(await t.cubit.swap('c1'), isFalse);
    expect(t.loaded.lastError?.code, 'network');
    expect(t.loaded.swappingId, 'M1-q1');
    expect(t.loaded.busy, isFalse);
  });

  test('MCK-03: delete returns true on success', () async {
    final t = _Setup();
    await t.cubit.load();
    expect(await t.cubit.delete(), isTrue);
    expect(t.mock.calls.last.$1, 'delete');
    expect(t.mock.calls.last.$2, ['c1', 1, 2]);
  });

  test('MCK-03: delete of a vanished form reloads to Missing', () async {
    final t = _Setup();
    await t.cubit.load();
    t.mock.deleteResult = const Failure(AppError('invalid_input'));
    t.mock.formResult = const Failure(AppError('invalid_input'));
    expect(await t.cubit.delete(), isFalse);
    expect(t.cubit.state, isA<MockFormMissing>());
  });

  test('MCK-03: published form refuses swap, publish and delete', () async {
    final t = _Setup();
    t.mock.formResult = Success(publishedForm);
    await t.cubit.load();
    await t.cubit.openSwap('M1-q1');
    expect(await t.cubit.swap('c1'), isFalse);
    await t.cubit.publish();
    expect(await t.cubit.delete(), isFalse);
    expect(
      t.mock.calls.map((c) => c.$1).toSet(),
      {'form'},
    );
  });
  test('MCK-03: openSwap reports whether it started', () async {
    final t = _Setup();
    await t.cubit.load();
    expect(t.cubit.canOpenSwap, isTrue);
    expect(await t.cubit.openSwap('M1-q1'), isTrue);
  });

  group('MCK-03: busy guards', () {
    test('a second publish while busy makes no second RPC', () async {
      final t = _Setup();
      await t.cubit.load();
      t.mock.gate = Completer<void>();
      final first = t.cubit.publish();
      await t.cubit.publish();
      expect(t.mock.count('publish'), 1);
      expect(t.loaded.busy, isTrue);
      t.mock.gate!.complete();
      await first;
      expect(t.loaded.busy, isFalse);
    });

    test('a second delete while busy makes no second RPC', () async {
      final t = _Setup();
      await t.cubit.load();
      t.mock.gate = Completer<void>();
      final first = t.cubit.delete();
      expect(await t.cubit.delete(), isFalse);
      expect(t.mock.count('delete'), 1);
      t.mock.gate!.complete();
      expect(await first, isTrue);
    });

    test('a second swap and openSwap while busy do nothing', () async {
      final t = _Setup();
      await t.cubit.load();
      await t.cubit.openSwap('M1-q1');
      t.mock.gate = Completer<void>();
      final first = t.cubit.swap('c1');
      expect(await t.cubit.swap('c2'), isFalse);
      expect(t.cubit.canOpenSwap, isFalse);
      final candidatesBefore = t.mock.count('candidates');
      expect(await t.cubit.openSwap('M1-q2'), isFalse);
      expect(t.mock.count('candidates'), candidatesBefore);
      expect(t.mock.count('swap'), 1);
      t.mock.gate!.complete();
      expect(await first, isTrue);
    });
  });

  test('MCK-03: a non-gone publish failure keeps the form editable', () async {
    final t = _Setup();
    await t.cubit.load();
    t.mock.publishResult = const Failure(AppError('network'));
    await t.cubit.publish();
    expect(t.loaded.lastError?.code, 'network');
    expect(t.loaded.isDraft, isTrue);
    expect(t.loaded.busy, isFalse);
    expect(t.mock.count('form'), 1);
    t.mock.publishResult = const Success(Published());
    t.mock.formResult = Success(publishedForm);
    await t.cubit.publish();
    expect(t.loaded.form.status, MockFormStatus.published);
  });

  test('MCK-03: a non-gone delete failure keeps the form editable', () async {
    final t = _Setup();
    await t.cubit.load();
    t.mock.deleteResult = const Failure(AppError('network'));
    expect(await t.cubit.delete(), isFalse);
    expect(t.loaded.lastError?.code, 'network');
    expect(t.loaded.isDraft, isTrue);
    expect(t.loaded.busy, isFalse);
    expect(t.mock.count('form'), 1);
    t.mock.deleteResult = const Success(null);
    expect(await t.cubit.delete(), isTrue);
  });

  test('MCK-03: closeSwap clears the sheet state', () async {
    final t = _Setup();
    await t.cubit.load();
    await t.cubit.openSwap('M1-q1');
    t.cubit.closeSwap();
    expect(t.loaded.swappingId, isNull);
    expect(t.loaded.candidates, isNull);
  });

  test('MCK-03: swap invalid_input uses the slot copy and reloads', () async {
    final t = _Setup();
    await t.cubit.load();
    await t.cubit.openSwap('M1-q1');
    t.mock.swapResult = const Failure(AppError('invalid_input'));
    final before = t.mock.count('form');
    expect(await t.cubit.swap('c1'), isFalse);
    expect(t.loaded.lastError?.code, mockSlotUnavailableCode);
    expect(t.loaded.swappingId, isNull);
    expect(t.mock.count('form'), before + 1);
    expect(
      mockErrorCopy(mockSlotUnavailableCode),
      'That question is no longer available for this slot.',
    );
  });

  test('MCK-03: preview closes when its question leaves the form', () async {
    final t = _Setup();
    await t.cubit.load();
    await t.cubit.openPreview('M1-q1');
    expect(t.loaded.preview, isNotNull);
    await t.cubit.openSwap('M1-q1');
    final swapped = _formReplacing('M1-q1', 'c1');
    t.mock.formResult = Success(swapped);
    await t.cubit.swap('c1');
    expect(t.loaded.previewId, isNull);
    expect(t.loaded.preview, isNull);
  });
}
