import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/teacher/mock/data/models/mock_models.dart';
import 'package:sat_east_client/features/teacher/mock/domain/entities/mock_entities.dart';
import 'package:sat_east_client/features/teacher/mock/domain/usecases/find_sat_course.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/cubit/mock_form_cubit.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/mock_copy.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/screens/mock_form_screen.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/widgets/mock_preview_panel.dart';

import '../../course_builder/builder_fixtures.dart';
import '../../questions/editor_fixtures.dart';
import '../mock_fakes.dart';
import '../mock_fixtures.dart';

class _H {
  _H(this.tester);
  final WidgetTester tester;
  final mock = FakeTeacherMockRepository();
  final editor = FakeEditorRepository();
  late MockFormCubit cubit;

  Future<void> pump({double width = 1280}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 1000);
    addTearDown(tester.view.reset);
    cubit = MockFormCubit(
      mock,
      editor,
      FindSatCourse(FakeBuilderRepository()),
      setNo: 1,
      formNo: 2,
    );
    addTearDown(cubit.close);
    await cubit.load();
    final router = GoRouter(
      initialLocation: AppRoutes.teacherMockForm(1, 2),
      routes: [
        GoRoute(
          path: AppRoutes.teacherMockExams,
          builder: (_, _) => const Text('Overview body'),
        ),
        GoRoute(
          path: '${AppRoutes.teacherMockExams}/:setNo/:formNo',
          builder: (_, _) => Scaffold(
            body: BlocProvider.value(
              value: cubit,
              child: const MockFormView(),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
    await tester.pumpAndSettle();
  }

  Future<void> settle() => tester.pumpAndSettle();

  Finder dialogButton(String label) => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.widgetWithText(FilledButton, label),
  );
}

MockForm _formWithNullDomain() {
  final json = formJson();
  final modules = json['modules']! as List<Object?>;
  final questions =
      (modules.first! as Map<String, Object?>)['questions']! as List<Object?>;
  (questions.first! as Map<String, Object?>)['domain'] = null;
  return mockFormFromJson(json);
}

void main() {
  testWidgets('MCK-03: draft form lists three modules with row details', (
    tester,
  ) async {
    final h = _H(tester);
    h.mock.formResult = Success(_formWithNullDomain());
    await h.pump();
    expect(find.text('Set 1 · Form 2'), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('Module 1 · 22 questions'), findsOneWidget);
    expect(find.text('Module 2 (easier) · 22 questions'), findsOneWidget);
    expect(find.text('Module 2 (harder) · 22 questions'), findsOneWidget);
    expect(find.text('REF-M1-1'), findsOneWidget);
    expect(find.text('No domain · Medium · MCQ'), findsOneWidget);
    expect(find.text('Algebra · Medium · SPR'), findsWidgets);
    expect(find.text('Stem M1 1'), findsOneWidget);
    expect(find.byTooltip(mockSwapTooltip), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('MCK-03: published form is read-only but previews', (
    tester,
  ) async {
    final h = _H(tester);
    h.mock.formResult = Success(publishedForm);
    await h.pump();
    expect(find.text('Published'), findsOneWidget);
    expect(find.textContaining('11 Nov 2026'), findsOneWidget);
    expect(find.text(mockPublishedReadOnly), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Publish'), findsNothing);
    expect(find.text(mockDeleteLabel), findsNothing);
    expect(find.byTooltip(mockSwapTooltip), findsNothing);
    await tester.tap(find.text('REF-M1-1'));
    await h.settle();
    expect(find.textContaining('Solve x.'), findsWidgets);
    expect(h.editor.gets, ['M1-q1']);
  });

  testWidgets('MCK-03: stale rows get text markers and a banner', (
    tester,
  ) async {
    final h = _H(tester);
    h.mock.publishResult = const Success(Stale(['M1-q1', 'M2E-q2']));
    await h.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Publish'));
    await h.settle();
    await tester.tap(h.dialogButton('Publish'));
    await h.settle();
    expect(find.text(mockStaleBanner(2)), findsOneWidget);
    expect(find.text(mockStaleMarker), findsNWidgets(2));
    expect(find.text('Draft'), findsOneWidget);
  });

  testWidgets('MCK-03: publish confirm cancel does nothing', (tester) async {
    final h = _H(tester);
    await h.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Publish'));
    await h.settle();
    expect(find.text(mockPublishTitle), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await h.settle();
    expect(h.mock.count('publish'), 0);
  });

  testWidgets('MCK-03: publish confirm publishes and shows published', (
    tester,
  ) async {
    final h = _H(tester);
    await h.pump();
    h.mock.formResult = Success(publishedForm);
    await tester.tap(find.widgetWithText(FilledButton, 'Publish'));
    await h.settle();
    await tester.tap(h.dialogButton('Publish'));
    await h.settle();
    expect(h.mock.count('publish'), 1);
    expect(find.text('Published'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Publish'), findsNothing);
  });

  testWidgets('MCK-03: already published elsewhere shows copy and reloads', (
    tester,
  ) async {
    final h = _H(tester);
    await h.pump();
    h.mock
      ..publishResult = const Failure(AppError('mock_form_published'))
      ..formResult = Success(publishedForm);
    await tester.tap(find.widgetWithText(FilledButton, 'Publish'));
    await h.settle();
    await tester.tap(h.dialogButton('Publish'));
    await h.settle();
    expect(find.text('This form is already published.'), findsOneWidget);
    expect(find.text('Published'), findsOneWidget);
    expect(find.byTooltip(mockSwapTooltip), findsNothing);
  });

  testWidgets('MCK-03: delete cancel does nothing', (tester) async {
    final h = _H(tester);
    await h.pump();
    await tester.tap(find.text(mockDeleteLabel));
    await h.settle();
    expect(find.text(mockDeleteTitle), findsWidgets);
    await tester.tap(find.text('Cancel'));
    await h.settle();
    expect(h.mock.count('delete'), 0);
    expect(find.text('Overview body'), findsNothing);
  });

  testWidgets('MCK-03: delete confirm returns to the overview', (tester) async {
    final h = _H(tester);
    await h.pump();
    await tester.tap(find.text(mockDeleteLabel));
    await h.settle();
    await tester.tap(h.dialogButton(mockDeleteLabel));
    await h.settle();
    expect(h.mock.count('delete'), 1);
    expect(find.text('Overview body'), findsOneWidget);
  });

  testWidgets('MCK-03: wide screen previews in a side panel', (tester) async {
    final h = _H(tester);
    await h.pump();
    await tester.tap(find.text('REF-M1-1'));
    await h.settle();
    expect(find.byType(MockPreviewPanel), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.textContaining('Solve x.'), findsWidgets);
    await tester.tap(find.byTooltip(mockClosePreview));
    await h.settle();
    expect(find.byType(MockPreviewPanel), findsNothing);
  });

  testWidgets('MCK-03: narrow screen previews in a bottom sheet', (
    tester,
  ) async {
    final h = _H(tester);
    await h.pump(width: 360);
    await tester.tap(find.text('REF-M1-1'));
    await h.settle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(MockPreviewPanel), findsNothing);
    expect(find.textContaining('Solve x.'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('MCK-03: preview failure shows error copy and retry', (
    tester,
  ) async {
    final h = _H(tester);
    h.editor.getResult = const Failure(AppError('forbidden'));
    await h.pump();
    await tester.tap(find.text('REF-M1-1'));
    await h.settle();
    expect(find.text(mockErrorCopy('forbidden')), findsOneWidget);
    h.editor.getResult = Success(editorDraft);
    await tester.tap(find.text('Retry'));
    await h.settle();
    expect(find.textContaining('Solve x.'), findsWidgets);
  });

  testWidgets('MCK-03: swap sheet lists candidates and swaps after confirm', (
    tester,
  ) async {
    final h = _H(tester);
    await h.pump();
    await tester.tap(find.byTooltip(mockSwapTooltip).first);
    await h.settle();
    expect(find.text('REF-C1'), findsOneWidget);
    await tester.tap(find.text('REF-C1'));
    await h.settle();
    expect(find.text(mockSwapConfirmTitle), findsWidgets);
    await tester.tap(h.dialogButton(mockSwapConfirmLabel));
    await h.settle();
    final swap = h.mock.calls.firstWhere((c) => c.$1 == 'swap');
    expect(swap.$2, ['c1', 1, 2, 'M1-q1', 'c1']);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('MCK-03: swap confirm cancel keeps the sheet and skips swap', (
    tester,
  ) async {
    final h = _H(tester);
    await h.pump();
    await tester.tap(find.byTooltip(mockSwapTooltip).first);
    await h.settle();
    await tester.tap(find.text('REF-C1'));
    await h.settle();
    await tester.tap(find.text('Cancel'));
    await h.settle();
    expect(h.mock.count('swap'), 0);
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('MCK-03: swap sheet with no candidates says so', (tester) async {
    final h = _H(tester);
    h.mock.candidatesResult = const Success([]);
    await h.pump();
    await tester.tap(find.byTooltip(mockSwapTooltip).first);
    await h.settle();
    expect(find.text(mockNoCandidates), findsOneWidget);
  });

  testWidgets('MCK-03: missing form shows a way back', (tester) async {
    final h = _H(tester);
    h.mock.formResult = const Failure(AppError('invalid_input'));
    await h.pump();
    expect(find.text(mockFormMissingTitle), findsOneWidget);
    await tester.tap(find.text(mockBackToList));
    await h.settle();
    expect(find.text('Overview body'), findsOneWidget);
  });

  for (final (set, form) in [('x', '1'), ('1', '0'), ('0', '2'), ('-1', '1')]) {
    testWidgets('MCK-03: bad params $set/$form show the missing page', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: MockFormScreen(setNo: set, formNo: form),
          ),
        ),
      );
      expect(find.text(mockFormMissingTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('MCK-03: 360 px draft form has no overflow', (tester) async {
    final h = _H(tester);
    await h.pump(width: 360);
    expect(tester.takeException(), isNull);
  });
}
