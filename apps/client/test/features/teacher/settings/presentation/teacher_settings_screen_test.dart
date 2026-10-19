import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/teacher/settings/data/models/setting_spec_model.dart';
import 'package:sat_east_client/features/teacher/settings/presentation/cubit/teacher_settings_cubit.dart';
import 'package:sat_east_client/features/teacher/settings/presentation/screens/teacher_settings_screen.dart';
import 'package:sat_east_client/features/teacher/shell/teacher_shell.dart';

import '../settings_fixtures.dart';

Finder get passMark => find.byKey(const ValueKey('setting-pass_mark'));
Future<FakeTeacherSettingsRepository> pumpSettings(
  WidgetTester tester, {
  double width = 1280,
  FakeTeacherSettingsRepository? repository,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1000);
  addTearDown(tester.view.reset);
  final repo = repository ?? FakeTeacherSettingsRepository();
  final cubit = TeacherSettingsCubit(repo, now: () => savedTime);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await cubit.close();
  });
  await cubit.load();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: TeacherShell(
        child: BlocProvider.value(
          value: cubit,
          child: const TeacherSettingsView(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  for (final width in [360.0, 1280.0]) {
    testWidgets('ADM-06: groups and server range fit $width', (tester) async {
      await pumpSettings(tester, width: width);
      for (final group in ['Quiz', 'Practice', 'Access', 'Devices', 'AI']) {
        expect(find.text(group), findsOneWidget);
      }
      final field = tester.widget<TextField>(passMark);
      expect(field.decoration?.helperText, '7\u201393');
      expect(field.decoration?.suffixText, '%');
      expect(find.text('Save changes'), findsNothing);
      await tester.enterText(passMark, '80');
      await tester.pumpAndSettle();
      expect(find.text('Save changes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('ADM-06: invalid integer shows the server-derived range error', (
    tester,
  ) async {
    await pumpSettings(tester);
    for (final input in ['abc', '7.5', '6', '94', '']) {
      await tester.enterText(passMark, input);
      await tester.pumpAndSettle();
      expect(find.text('Enter a whole number from 7 to 93'), findsOneWidget);
      final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save changes'),
      );
      expect(save.onPressed, isNull);
    }
  });
  testWidgets('ADM-06: discard restores controllers and clears dirty bar', (
    tester,
  ) async {
    final repo = await pumpSettings(tester);
    await tester.enterText(passMark, '80');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(passMark).controller?.text, '75');
    expect(find.text('Save changes'), findsNothing);
    expect(repo.saves, isEmpty);
  });
  testWidgets('ADM-06: successful save reloads and announces success', (
    tester,
  ) async {
    final repo = await pumpSettings(tester);
    await tester.enterText(passMark, '80');
    await tester.pumpAndSettle();
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
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();
    expect(repo.saves, [
      {'pass_mark': 80},
    ]);
    expect(find.text('Settings saved'), findsOneWidget);
    expect(find.text('Save changes'), findsNothing);
    expect(tester.widget<TextField>(passMark).controller?.text, '80');
    await tester.enterText(passMark, '81');
    await tester.pumpAndSettle();
    expect(find.text('Settings saved'), findsNothing);
    expect(find.text('Discard').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(passMark).controller?.text, '80');
  });
  testWidgets('ADM-06: server rejection preserves draft and shows safe copy', (
    tester,
  ) async {
    final repo = FakeTeacherSettingsRepository()
      ..saveResult = const Failure(
        AppError(ErrorCodes.invalidInput, 'raw secret'),
      );
    await pumpSettings(tester, repository: repo);
    await tester.enterText(passMark, '80');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();
    expect(
      find.text('Some values are out of range. Nothing was saved.'),
      findsOneWidget,
    );
    expect(find.text('raw secret'), findsNothing);
    expect(tester.widget<TextField>(passMark).controller?.text, '80');
    expect(find.text('Save changes'), findsOneWidget);
  });
  testWidgets('ADM-06: failed load can retry', (tester) async {
    final repo = FakeTeacherSettingsRepository()
      ..loadResult = const Failure(AppError(ErrorCodes.network));
    await pumpSettings(tester, repository: repo);
    repo.loadResult = Success(settingsSpecs);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(passMark, findsOneWidget);
  });
  testWidgets('ADM-06: empty spec has an explicit state', (tester) async {
    await pumpSettings(
      tester,
      repository: FakeTeacherSettingsRepository()
        ..loadResult = const Success([]),
    );
    expect(find.text('No settings available.'), findsOneWidget);
    expect(find.text('Save changes'), findsNothing);
  });
}
