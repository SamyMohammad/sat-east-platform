import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/teacher/notes/presentation/cubit/teacher_notes_cubit.dart';
import 'package:sat_east_client/features/teacher/notes/presentation/screens/teacher_notes_screen.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/picked_file.dart';
import 'package:sat_east_client/features/teacher/questions/domain/services/file_picker_service.dart';
import 'package:sat_east_client/features/teacher/shell/teacher_shell.dart';

import '../../review/review_fixtures.dart';
import '../notes_fixtures.dart';

class _Picker implements FilePickerService {
  @override
  Future<Result<PickedPdf>> pickPdf() async => Success(pdf());
  @override
  Future<Result<PickedFile>> pickJson() async =>
      const Failure(AppError('cancelled'));
}

Future<FakeTeacherNotesRepository> pumpNotes(
  WidgetTester tester, {
  double width = 1280,
  FakeTeacherNotesRepository? repository,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1000);
  addTearDown(tester.view.reset);
  final repo = repository ?? FakeTeacherNotesRepository();
  final cubit = TeacherNotesCubit(actions(repo, picker: _Picker()));
  getIt.registerFactory<TeacherNotesCubit>(() => cubit);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await getIt.unregister<TeacherNotesCubit>();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: const TeacherShell(
        child: TeacherNotesScreen(courseId: 'c1', topicId: 't1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  setUp(registerReviewFakes);
  tearDown(unregisterReviewFakes);
  for (final width in [360.0, 1280.0]) {
    testWidgets(
      'C-3: notes manager fits $width and offers only topic subtopics',
      (tester) async {
        await pumpNotes(tester, width: width);
        expect(find.text('Algebra notes'), findsOneWidget);
        expect(find.text('Upload PDF'), findsOneWidget);
        expect(find.text('PDF up to 1 MB'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('subtopic-a1')));
        await tester.pumpAndSettle();
        expect(find.text('One step'), findsWidgets);
        expect(find.text('Other topic'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('C-3: upload shows progress and disables repeat actions', (
    tester,
  ) async {
    final pending = Completer<Result<void>>();
    final repo = FakeTeacherNotesRepository()..pending = pending.future;
    await pumpNotes(tester, repository: repo);
    await tester.tap(find.text('Upload PDF'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byWidgetPredicate((widget) => widget is FilledButton),
          )
          .onPressed,
      isNull,
    );
    pending.complete(const Success(null));
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(repo.calls, contains('confirm:new'));
  });
  testWidgets('C-3: rename, subtopic and move trigger exact changes', (
    tester,
  ) async {
    final repo = await pumpNotes(tester);
    await tester.tap(find.byKey(const ValueKey('rename-a1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Updated');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('update:a1:Updated:null'));
    await tester.tap(find.byKey(const ValueKey('subtopic-a1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('One step').last);
    await tester.pumpAndSettle();
    expect(repo.calls, contains('update:a1:Algebra notes:s1'));
    await tester.tap(find.byKey(const ValueKey('up-a2')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('reorder:t1:a2,a1'));
  });
  testWidgets('C-3: deleting requires confirmation and removes object first', (
    tester,
  ) async {
    final repo = await pumpNotes(tester);
    await tester.tap(find.byKey(const ValueKey('delete-a1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.calls.where((s) => s.startsWith('remove:')), isEmpty);
    await tester.tap(find.byKey(const ValueKey('delete-a1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(repo.calls.sublist(repo.calls.length - 3), [
      'remove:t1/a1.pdf',
      'delete:a1',
      'list:t1',
    ]);
  });
  testWidgets('C-3: failed subtopic change restores saved selection', (
    tester,
  ) async {
    final repo = FakeTeacherNotesRepository()
      ..failures['update'] = const AppError('network');
    await pumpNotes(tester, repository: repo);
    await tester.tap(find.byKey(const ValueKey('subtopic-a1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('One step').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButton<String>>(
            find.byKey(const ValueKey('subtopic-a1')),
          )
          .value,
      isNull,
    );
  });
  testWidgets('C-3: failed writes show one friendly error', (tester) async {
    final repo = FakeTeacherNotesRepository()
      ..failures['upload'] = const AppError('forbidden');
    await pumpNotes(tester, repository: repo);
    await tester.tap(find.text('Upload PDF'));
    await tester.pumpAndSettle();
    expect(find.text('Only the teacher can change the notes.'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });
  testWidgets('C-3: empty notes still offer upload', (tester) async {
    final repo = FakeTeacherNotesRepository()..listResult = const Success([]);
    await pumpNotes(tester, repository: repo);
    expect(find.text('No notes yet.'), findsOneWidget);
    expect(find.text('Upload PDF'), findsOneWidget);
  });
}
