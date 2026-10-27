import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/observability/error_reporter.dart';
import 'package:sat_east_client/core/theme/theme_mode_cubit.dart';
import 'package:sat_east_client/core/theme/theme_mode_store.dart';

class _Box extends Mock implements Box<String> {}

class _Reporter extends Mock implements ErrorReporter {}

void main() {
  late Directory directory;
  late Box<String> box;
  late ThemeModeCubit cubit;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('theme_mode_');
    box = await Hive.openBox<String>(
      directory.uri.pathSegments.where((segment) => segment.isNotEmpty).last,
      path: directory.path,
    );
    cubit = ThemeModeCubit(ThemeModeStore(box, const NoopErrorReporter()));
  });
  tearDown(() async {
    await cubit.close();
    await box.close();
    await directory.delete(recursive: true);
  });

  test('defaults_to_system_when_empty', () {
    cubit.load();
    expect(cubit.state, ThemeMode.system);
  });
  test('defaults_to_system_when_value_unknown', () async {
    await box.put('themeMode', 'corrupt');
    cubit.load();
    expect(cubit.state, ThemeMode.system);
  });
  test('set_persists_and_emits', () async {
    final states = cubit.stream.take(3).toList();
    for (final mode in [ThemeMode.dark, ThemeMode.light, ThemeMode.system]) {
      await cubit.set(mode);
      expect(cubit.state, mode);
      expect(box.get('themeMode'), mode.name);
    }
    expect(await states, [ThemeMode.dark, ThemeMode.light, ThemeMode.system]);
  });
  test('load_reads_persisted', () async {
    await cubit.set(ThemeMode.dark);
    final name = box.name;
    await box.close();
    box = await Hive.openBox<String>(name, path: directory.path);
    final restarted = ThemeModeCubit(
      ThemeModeStore(box, const NoopErrorReporter()),
    )..load();
    expect(restarted.state, ThemeMode.dark);
    await restarted.close();
  });
  test('corrupt_read_falls_back_and_reports', () {
    final broken = _Box();
    final reporter = _Reporter();
    final error = StateError('unreadable preference');
    when(() => broken.get('themeMode')).thenThrow(error);
    when(
      () => reporter.captureError(error, any(), hint: any(named: 'hint')),
    ).thenAnswer((_) async {});
    final store = ThemeModeStore(broken, reporter);
    expect(store.read(), ThemeMode.system);
    verify(
      () => reporter.captureError(error, any(), hint: any(named: 'hint')),
    ).called(1);
  });
  test('failed_write_keeps_current_mode_and_reports', () async {
    final broken = _Box();
    final reporter = _Reporter();
    final error = StateError('storage unavailable');
    when(() => broken.put('themeMode', 'dark')).thenThrow(error);
    when(
      () => reporter.captureError(error, any(), hint: any(named: 'hint')),
    ).thenAnswer((_) async {});
    final failing = ThemeModeCubit(ThemeModeStore(broken, reporter));
    await failing.set(ThemeMode.dark);
    expect(failing.state, ThemeMode.system);
    verify(
      () => reporter.captureError(error, any(), hint: any(named: 'hint')),
    ).called(1);
    await failing.close();
  });
}
