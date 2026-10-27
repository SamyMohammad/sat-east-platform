import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/import_report.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/question_save_result.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_editor_cubit.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/screens/question_editor_screen.dart';
import 'package:sat_east_client/features/teacher/shell/teacher_shell.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';
import 'package:sat_east_client/shared/widgets/question_view/practice_feedback.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_data.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view_mode.dart';

import '../../review/review_fixtures.dart';
import '../bank_fixtures.dart';
import '../editor_fixtures.dart';

Future<GoRouter> pumpEditor(
  WidgetTester tester,
  QuestionEditorCubit cubit, {
  double width = 1280,
  bool create = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1000);
  addTearDown(tester.view.reset);
  getIt.registerFactory<QuestionEditorCubit>(() => cubit);
  final key = GlobalKey<QuestionEditorScreenState>();
  final router = GoRouter(
    initialLocation: create
        ? '/teacher/questions/new'
        : '/teacher/questions/q1',
    routes: [
      GoRoute(
        path: '/teacher/questions',
        builder: (_, _) => const Text('Bank body'),
      ),
      GoRoute(
        path: '/teacher/questions/new',
        builder: (_, _) => TeacherShell(child: QuestionEditorScreen(key: key)),
        onExit: (_, _) => key.currentState?.confirmLeave() ?? true,
      ),
      GoRoute(
        path: '/teacher/questions/:id',
        builder: (_, state) => create
            ? Text('Created ${state.pathParameters['id']}')
            : TeacherShell(
                child: QuestionEditorScreen(
                  key: key,
                  questionId: state.pathParameters['id'],
                ),
              ),
        onExit: (_, _) => key.currentState?.confirmLeave() ?? true,
      ),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    router.dispose();
    await getIt.unregister<QuestionEditorCubit>();
  });
  await tester.pumpWidget(
    MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  setUp(registerReviewFakes);
  tearDown(unregisterReviewFakes);
  testWidgets(
    'T-08: report resolution hides panel and preserves dirty editor',
    (tester) async {
      await unregisterReviewFakes();
      final reports = FakeReviewRepository()..reportsValue = openReports;
      registerReviewFakes(repository: reports);
      final cubit = QuestionEditorCubit(
        FakeEditorRepository(),
        FakeBankRepository(),
      );
      await pumpEditor(tester, cubit);
      expect(find.text('Reports'), findsOneWidget);
      expect(find.text('Student name'), findsOneWidget);
      expect(find.text('Answer key is wrong'), findsOneWidget);
      expect(find.text('<b>Plain report</b>'), findsOneWidget);
      cubit.editContent(stemMd: 'Changed draft');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark fixed'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Optional note'),
        'Resolved',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Mark fixed'),
        ),
      );
      await tester.pumpAndSettle();
      expect(reports.resolutions, [('q1', 'fixed', 'Resolved')]);
      expect(find.text('Reports'), findsNothing);
      expect(cubit.state.draft?.stemMd, 'Changed draft');
      expect(cubit.state.isDirty, isTrue);
    },
  );
  for (final width in [360.0, 1280.0]) {
    testWidgets('QB-06: editor and real preview fit $width', (tester) async {
      await pumpEditor(
        tester,
        QuestionEditorCubit(FakeEditorRepository(), FakeBankRepository()),
        width: width,
      );
      final preview = tester.widget<QuestionView>(find.byType(QuestionView));
      expect(preview.showNavigation, isFalse);
      expect(preview.mode, isA<PracticeMode>());
      expect((preview.mode as PracticeMode).feedback, isA<Correct>());
      expect(preview.answer.selected, 'B');
      expect(preview.question.kind, isA<McqKind>());
      expect(find.widgetWithText(LoadingButton, 'Save'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  for (final width in [360.0, 1280.0]) {
    testWidgets('QB-06: error summary counts, jumps and clears at $width', (
      tester,
    ) async {
      final repo = FakeEditorRepository()
        ..saveResult = Success(
          QuestionRejected(const [
            ImportProblem(
              row: 1,
              externalRef: 'EDIT_1',
              field: 'status',
              problem: 'bad_status_change',
            ),
            ImportProblem(
              row: 1,
              externalRef: 'EDIT_1',
              field: 'source_page',
              problem: 'missing:source_page',
            ),
          ]),
        );
      await pumpEditor(
        tester,
        QuestionEditorCubit(repo, FakeBankRepository()),
        width: width,
      );
      await tester.enterText(
        find.byKey(const ValueKey('editor-stem_md')),
        'Changed',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('2 problems to fix before saving.'), findsOneWidget);
      expect(
        find.text('Status: This status change is not allowed.'),
        findsOneWidget,
      );
      final summary = find.byKey(const ValueKey('editor-error-summary'));
      expect(tester.getRect(summary).top, greaterThanOrEqualTo(0));
      for (final (field, copy) in [
        ('status', 'Status: This status change is not allowed.'),
        ('source_page', 'Source page: Missing or invalid source_page.'),
      ]) {
        final link = find.widgetWithText(TextButton, copy);
        await tester.ensureVisible(link);
        await tester.tap(link);
        await tester.pumpAndSettle();
        final target = find.byKey(ValueKey('editor-$field'));
        final scroll = find
            .ancestor(of: target, matching: find.byType(SingleChildScrollView))
            .first;
        final rect = tester.getRect(target);
        final viewport = tester.getRect(scroll);
        expect(rect.top, greaterThanOrEqualTo(viewport.top - 1));
        expect(rect.bottom, lessThanOrEqualTo(viewport.bottom + 1));
      }
      await tester.enterText(
        find.byKey(const ValueKey('editor-source_page')),
        '8',
      );
      await tester.pumpAndSettle();
      expect(find.text('1 problem to fix before saving.'), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('editor-error-summary')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('QB-06: radio key and SPR switch drive the preview', (
    tester,
  ) async {
    await pumpEditor(
      tester,
      QuestionEditorCubit(FakeEditorRepository(), FakeBankRepository()),
    );
    await tester.ensureVisible(find.byKey(const ValueKey('editor-key-A')));
    await tester.tap(find.byKey(const ValueKey('editor-key-A')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<QuestionView>(find.byType(QuestionView)).answer.selected,
      'A',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('editor-type')));
    await tester.tap(find.byKey(const ValueKey('editor-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SPR').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('editor-accepted')));
    await tester.enterText(
      find.byKey(const ValueKey('editor-accepted')),
      '7/2\n3.5',
    );
    await tester.pumpAndSettle();
    final preview = tester.widget<QuestionView>(find.byType(QuestionView));
    expect(preview.question.kind, isA<SprKind>());
    expect(preview.answer.sprText, '7/2');
  });
  testWidgets(
    'QB-06: server problems show at their field and discard resets controller',
    (tester) async {
      final repo = FakeEditorRepository()
        ..saveResult = Success(
          QuestionRejected(const [
            ImportProblem(
              row: 1,
              externalRef: 'EDIT_1',
              field: 'stem_md',
              problem: 'missing:stem_md',
            ),
          ]),
        );
      await pumpEditor(tester, QuestionEditorCubit(repo, FakeBankRepository()));
      await tester.enterText(find.byKey(const ValueKey('editor-stem_md')), '');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Missing or invalid stem_md.'), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('editor-stem_md')))
            .controller
            ?.text,
        'Solve x.',
      );
    },
  );
  testWidgets('QB-06: conflict banner reloads latest saved question', (
    tester,
  ) async {
    final repo = FakeEditorRepository()
      ..saveResult = const Failure(AppError('version_conflict'));
    await pumpEditor(tester, QuestionEditorCubit(repo, FakeBankRepository()));
    await tester.enterText(
      find.byKey(const ValueKey('editor-stem_md')),
      'Changed',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      find.text('This question changed elsewhere. Reload to see the latest.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Reload'));
    await tester.pumpAndSettle();
    expect(
      find.text('This question changed elsewhere. Reload to see the latest.'),
      findsNothing,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('editor-stem_md')))
          .controller
          ?.text,
      'Solve x.',
    );
  });
  testWidgets('QB-06: unsaved navigation requires explicit discard', (
    tester,
  ) async {
    final router = await pumpEditor(
      tester,
      QuestionEditorCubit(FakeEditorRepository(), FakeBankRepository()),
    );
    await tester.enterText(
      find.byKey(const ValueKey('editor-stem_md')),
      'Changed',
    );
    await tester.pumpAndSettle();
    router.go('/teacher/questions');
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/teacher/questions/q1',
    );
    router.go('/teacher/questions');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Discard').last);
    await tester.pumpAndSettle();
    expect(find.text('Bank body'), findsOneWidget);
  });
  testWidgets('QB-06: create navigates to the returned question id', (
    tester,
  ) async {
    final repo = FakeEditorRepository()
      ..saveResult = const Success(QuestionSaved(id: 'qnew', version: 1));
    final router = await pumpEditor(
      tester,
      QuestionEditorCubit(repo, FakeBankRepository()),
      create: true,
    );
    await tester.enterText(
      find.byKey(const ValueKey('editor-stem_md')),
      'New stem',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/teacher/questions/qnew',
    );
    expect(find.text('Created qnew'), findsOneWidget);
  });
}
