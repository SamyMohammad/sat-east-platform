import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/teacher/settings/presentation/cubit/delete_student_cubit.dart';
import 'package:sat_east_client/features/teacher/settings/presentation/widgets/delete_student_card.dart';

import '../settings_fixtures.dart';

Future<FakeTeacherSettingsRepository> pumpCard(
  WidgetTester tester, {
  double width = 1280,
  FakeTeacherSettingsRepository? repository,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.reset);
  final repo = repository ?? FakeTeacherSettingsRepository();
  final cubit = DeleteStudentCubit(repo);
  addTearDown(cubit.close);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: BlocProvider.value(
            value: cubit,
            child: const DeleteStudentCard(),
          ),
        ),
      ),
    ),
  );
  return repo;
}

final Finder emailField = find.byKey(const ValueKey('delete-student-email'));
final Finder confirmField = find.byKey(
  const ValueKey('delete-student-confirm'),
);
Finder get openButton => find.widgetWithText(FilledButton, 'Delete student');
Finder get confirmButton =>
    find.widgetWithText(FilledButton, 'Delete permanently');

Future<void> openDialog(WidgetTester tester, String email) async {
  await tester.enterText(emailField, email);
  await tester.pump();
  await tester.tap(openButton);
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [360.0, 1280.0]) {
    testWidgets('P3: card fits $width and starts disabled', (tester) async {
      await pumpCard(tester, width: width);
      expect(find.text('Delete a student'), findsOneWidget);
      expect(tester.widget<FilledButton>(openButton).onPressed, isNull);
      await openDialog(tester, 'a@b.com');
      expect(find.text('Delete permanently'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('P3: confirm stays disabled until the email is retyped exactly', (
    tester,
  ) async {
    final repo = await pumpCard(tester);
    await openDialog(tester, 'a@b.com');
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);
    await tester.enterText(confirmField, 'a@b.co');
    await tester.pump();
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);
    await tester.tap(confirmButton, warnIfMissed: false);
    await tester.pump();
    expect(repo.deletes, isEmpty);
    await tester.enterText(confirmField, 'a@b.com');
    await tester.pump();
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNotNull);
  });
  testWidgets('P3: cancel does not delete', (tester) async {
    final repo = await pumpCard(tester);
    await openDialog(tester, 'a@b.com');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.deletes, isEmpty);
  });
  testWidgets('P3: confirmed delete calls the repository and clears the form', (
    tester,
  ) async {
    final repo = await pumpCard(tester);
    await openDialog(tester, 'a@b.com');
    await tester.enterText(confirmField, 'a@b.com');
    await tester.pump();
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();
    expect(repo.deletes, ['a@b.com']);
    expect(find.text('Student deleted'), findsOneWidget);
    expect(tester.widget<TextField>(emailField).controller?.text, isEmpty);
  });
  for (final entry in {
    ErrorCodes.studentNotFound: 'No student has that email.',
    ErrorCodes.studentHasOrders:
        'This student has payment records and cannot be deleted here.',
    ErrorCodes.forbidden:
        'Only student accounts can be deleted, and only by a teacher.',
    ErrorCodes.rateLimited: 'Too many deletions. Try again later.',
    ErrorCodes.network:
        "Couldn't delete the student. Check your connection and try again.",
  }.entries) {
    testWidgets('P3: ${entry.key} shows safe copy', (tester) async {
      final repo = FakeTeacherSettingsRepository()
        ..deleteResult = Failure(AppError(entry.key, 'raw secret'));
      await pumpCard(tester, repository: repo);
      await openDialog(tester, 'a@b.com');
      await tester.enterText(confirmField, 'a@b.com');
      await tester.pump();
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
      expect(find.text('raw secret'), findsNothing);
      expect(tester.widget<TextField>(emailField).controller?.text, 'a@b.com');
    });
  }
}
