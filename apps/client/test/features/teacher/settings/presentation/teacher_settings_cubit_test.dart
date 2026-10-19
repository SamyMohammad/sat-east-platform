import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/settings/data/models/setting_spec_model.dart';
import 'package:sat_east_client/features/teacher/settings/domain/entities/setting_spec.dart';
import 'package:sat_east_client/features/teacher/settings/presentation/cubit/teacher_settings_cubit.dart';
import 'package:sat_east_client/features/teacher/settings/presentation/cubit/teacher_settings_state.dart';

import '../settings_fixtures.dart';

void main() {
  late FakeTeacherSettingsRepository repo;
  late TeacherSettingsCubit cubit;
  setUp(() {
    repo = FakeTeacherSettingsRepository();
    cubit = TeacherSettingsCubit(repo, now: () => savedTime);
  });
  tearDown(() => cubit.close());
  test('ADM-06: loads server specs with a clean draft', () async {
    await cubit.load();
    final loaded = cubit.state as TeacherSettingsLoaded;
    expect(loaded.specs, settingsSpecs);
    expect(loaded.edits, isEmpty);
    expect(loaded.saving, isFalse);
    expect(loaded.isDirty, isFalse);
  });
  test('ADM-06: load failure can be retried', () async {
    repo.loadResult = const Failure(AppError(ErrorCodes.forbidden));
    await cubit.load();
    expect(
      (cubit.state as TeacherSettingsFailed).error.code,
      ErrorCodes.forbidden,
    );
    repo.loadResult = Success(settingsSpecs);
    await cubit.load();
    expect(cubit.state, isA<TeacherSettingsLoaded>());
  });
  test(
    'ADM-06: edit validates using server ranges and removes unchanged values',
    () async {
      await cubit.load();
      cubit.edit('pass_mark', 7);
      expect((cubit.state as TeacherSettingsLoaded).canSave, isTrue);
      cubit.edit('pass_mark', 6);
      expect((cubit.state as TeacherSettingsLoaded).invalidKeys, {'pass_mark'});
      cubit.edit('pass_mark', null);
      expect((cubit.state as TeacherSettingsLoaded).canSave, isFalse);
      cubit.edit('pass_mark', 75);
      expect((cubit.state as TeacherSettingsLoaded).isDirty, isFalse);
    },
  );
  test('ADM-06: unknown edit is rejected', () async {
    await cubit.load();
    cubit.edit('currency_by_country', 1);
    expect(
      (cubit.state as TeacherSettingsLoaded).lastError?.code,
      ErrorCodes.invalidInput,
    );
    expect((cubit.state as TeacherSettingsLoaded).edits, isEmpty);
  });
  test(
    'ADM-06: save sends only edits different from persisted values '
    'then reloads',
    () async {
      await cubit.load();
      cubit
        ..edit('pass_mark', 80)
        ..edit('homework_size', 20);
      await cubit.save();
      expect(repo.saves, [
        {'pass_mark': 80},
      ]);
      expect(repo.loads, 2);
      final loaded = cubit.state as TeacherSettingsLoaded;
      expect(loaded.edits, isEmpty);
      expect(loaded.savedAt, savedTime);
    },
  );
  test('ADM-06: discard after save restores the reloaded baseline', () async {
    await cubit.load();
    cubit.edit('pass_mark', 80);
    repo.loadResult = Success(
      settingsJson
          .map(
            (json) => settingSpecFromJson({
              ...json,
              if (json['key'] == 'pass_mark') 'value': 80,
            }),
          )
          .toList(),
    );
    await cubit.save();
    cubit.edit('pass_mark', 81);
    expect((cubit.state as TeacherSettingsLoaded).edits, {'pass_mark': 81});
    cubit.discard();
    final loaded = cubit.state as TeacherSettingsLoaded;
    expect(
      loaded.specs.singleWhere((spec) => spec.key == 'pass_mark').value,
      80,
    );
    expect(loaded.edits, isEmpty);
    expect(loaded.invalidKeys, isEmpty);
    expect(loaded.isDirty, isFalse);
    expect(repo.saves, [
      {'pass_mark': 80},
    ]);
  });
  test('ADM-06: save failure preserves draft and propagates error', () async {
    await cubit.load();
    cubit.edit('pass_mark', 80);
    repo.saveResult = const Failure(AppError(ErrorCodes.invalidInput));
    await cubit.save();
    final loaded = cubit.state as TeacherSettingsLoaded;
    expect(loaded.edits, {'pass_mark': 80});
    expect(loaded.saving, isFalse);
    expect(loaded.lastError?.code, ErrorCodes.invalidInput);
    expect(loaded.savedAt, isNull);
    expect(repo.loads, 1);
  });
  test('ADM-06: reload failure after save keeps draft available', () async {
    await cubit.load();
    cubit.edit('pass_mark', 80);
    repo.loadResult = const Failure(AppError(ErrorCodes.network));
    await cubit.save();
    expect(
      (cubit.state as TeacherSettingsLoaded).lastError?.code,
      ErrorCodes.network,
    );
    expect((cubit.state as TeacherSettingsLoaded).savedAt, isNull);
  });
  test('ADM-06: invalid or empty draft cannot save', () async {
    await cubit.load();
    await cubit.save();
    cubit.edit('pass_mark', null);
    await cubit.save();
    expect(repo.saves, isEmpty);
  });
  test('ADM-06: discard clears edits, validation and save errors', () async {
    await cubit.load();
    cubit
      ..edit('pass_mark', null)
      ..discard();
    final loaded = cubit.state as TeacherSettingsLoaded;
    expect(loaded.edits, isEmpty);
    expect(loaded.invalidKeys, isEmpty);
    expect(loaded.lastError, isNull);
  });
  test(
    'ADM-06: pending save blocks duplicate save, edits and discard',
    () async {
      await cubit.load();
      cubit.edit('pass_mark', 80);
      final pending = Completer<Result<void>>();
      repo.pendingSave = pending.future;
      final future = cubit.save();
      cubit
        ..edit('pass_mark', 85)
        ..discard();
      await cubit.save();
      expect(repo.saves, [
        {'pass_mark': 80},
      ]);
      expect((cubit.state as TeacherSettingsLoaded).edits, {'pass_mark': 80});
      pending.complete(const Success(null));
      await future;
    },
  );
  test('ADM-06: late load cannot overwrite a newer load', () async {
    final pending = Completer<Result<List<SettingSpec>>>();
    final started = Completer<void>();
    repo
      ..pendingLoad = pending.future
      ..onLoad = started.complete;
    final first = cubit.load();
    await started.future;
    repo
      ..pendingLoad = null
      ..onLoad = null;
    await cubit.load();
    final latest = cubit.state;
    pending.complete(const Failure(AppError(ErrorCodes.network)));
    await first;
    expect(cubit.state, same(latest));
  });
  test('ADM-06: closing during save does not emit or reload', () async {
    await cubit.load();
    cubit.edit('pass_mark', 80);
    final pending = Completer<Result<void>>();
    repo.pendingSave = pending.future;
    final future = cubit.save();
    await cubit.close();
    pending.complete(const Success(null));
    await expectLater(future, completes);
    expect(repo.loads, 1);
  });
}
