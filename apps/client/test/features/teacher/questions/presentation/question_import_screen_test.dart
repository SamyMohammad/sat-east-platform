import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/teacher/questions/data/services/file_picker_stub.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/picked_file.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_import_cubit.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/screens/question_import_screen.dart';
import 'package:sat_east_client/features/teacher/shell/teacher_shell.dart';

import '../import_fixtures.dart';

Future<void> pumpImport(
  WidgetTester tester,
  QuestionImportCubit cubit, {
  double width = 1280,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1000);
  addTearDown(tester.view.reset);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await cubit.close();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: TeacherShell(
        child: BlocProvider.value(
          value: cubit,
          child: const QuestionImportView(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [360.0, 1280.0]) {
    testWidgets('QB-05: errors and disabled import fit $width', (tester) async {
      final repo = FakeImportRepository()..dryResult = Success(badReport);
      final cubit = QuestionImportCubit(repo, FakeFilePicker());
      await pumpImport(tester, cubit, width: width);
      await tester.tap(find.text('Choose file'));
      await tester.pumpAndSettle();
      expect(find.text('bank.json'), findsOneWidget);
      expect(find.text('2 rows'), findsOneWidget);
      expect(find.text('Showing first 200'), findsOneWidget);
      expect(find.byType(DataTable), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Import 2 questions'),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('QB-05: clean import shows success and can reset', (
    tester,
  ) async {
    final cubit = QuestionImportCubit(FakeImportRepository(), FakeFilePicker());
    await pumpImport(tester, cubit);
    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import 2 questions'));
    await tester.pumpAndSettle();
    expect(find.text('Imported 2 questions'), findsOneWidget);
    await tester.tap(find.text('Import another'));
    await tester.pumpAndSettle();
    expect(find.text('Choose file'), findsOneWidget);
  });
  testWidgets('QB-05: stub picker explains web support', (tester) async {
    final cubit = QuestionImportCubit(
      FakeImportRepository(),
      StubFilePickerService(),
    );
    await pumpImport(tester, cubit);
    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();
    expect(find.text('Import works in the web app.'), findsOneWidget);
  });
  testWidgets('QB-05: malformed JSON shows safe copy', (tester) async {
    final picker = FakeFilePicker()
      ..result = const Success(PickedFile(name: 'bad', text: '{}'));
    await pumpImport(
      tester,
      QuestionImportCubit(FakeImportRepository(), picker),
    );
    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();
    expect(
      find.text("This file isn't a JSON array of questions."),
      findsOneWidget,
    );
  });
}
