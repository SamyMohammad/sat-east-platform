import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/math_render/math_text.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/bank_page.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_bank_cubit.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/screens/question_bank_screen.dart';
import 'package:sat_east_client/features/teacher/shell/teacher_shell.dart';

import '../bank_fixtures.dart';

Future<GoRouter> pumpBank(
  WidgetTester tester,
  QuestionBankCubit cubit, {
  double width = 1280,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1200);
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/teacher/questions',
    routes: [
      GoRoute(
        path: '/teacher/questions',
        builder: (_, _) => TeacherShell(
          child: BlocProvider.value(
            value: cubit,
            child: const QuestionBankView(),
          ),
        ),
      ),
      GoRoute(
        path: '/teacher/questions/import',
        builder: (_, _) => const Text('Import body'),
      ),
      GoRoute(
        path: '/teacher/questions/new',
        builder: (_, _) => const Text('New editor'),
      ),
      GoRoute(
        path: '/teacher/questions/:id',
        builder: (_, state) => Text('Editor ${state.pathParameters['id']}'),
      ),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    router.dispose();
    await cubit.close();
  });
  await cubit.load();
  await tester.pumpWidget(
    MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  for (final width in [360.0, 1280.0]) {
    testWidgets('QB-06: bank table and filters fit $width', (tester) async {
      final repo = FakeBankRepository();
      final cubit = QuestionBankCubit(
        repo,
        schedule: FakeBankScheduler().schedule,
      );
      final router = await pumpBank(tester, cubit, width: width);
      expect(find.byType(MathText), findsWidgets);
      final mathContext = tester.element(find.byType(MathText).first);
      expect(
        mathContext.findAncestorWidgetOfExactType<DefaultTextStyle>()?.maxLines,
        1,
      );
      expect(
        mathContext.findAncestorWidgetOfExactType<DefaultTextStyle>()?.softWrap,
        isFalse,
      );
      expect(
        find.text('1\u20132 of 3'),
        findsOneWidget,
      );
      expect(find.text('Published'), findsOneWidget);
      await tester.ensureVisible(find.text('BANK_1'));
      await tester.tap(find.text('BANK_1'));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/teacher/questions/q1',
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('QB-06: filter selection sends query and resets page', (
    tester,
  ) async {
    final repo = FakeBankRepository();
    await pumpBank(
      tester,
      QuestionBankCubit(repo, schedule: FakeBankScheduler().schedule),
    );
    await tester.tap(find.byKey(const ValueKey('bank-filter-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SPR').last);
    await tester.pumpAndSettle();
    expect(repo.calls.last.$1.type, 'spr');
  });
  testWidgets('QB-06: search field uses the injected debounce', (tester) async {
    final repo = FakeBankRepository();
    final scheduler = FakeBankScheduler();
    final cubit = QuestionBankCubit(repo, schedule: scheduler.schedule);
    await pumpBank(tester, cubit);
    await tester.enterText(find.byKey(const ValueKey('bank-search')), 'A_%');
    await tester.pump();
    expect(repo.calls.length, 1);
    expect(scheduler.pending, 1);
    scheduler.fire();
    await tester.pumpAndSettle();
    expect(repo.calls.last.$1.q, 'A_%');
  });
  testWidgets('QB-06: server page size drives pager', (tester) async {
    final repo = FakeBankRepository();
    await pumpBank(
      tester,
      QuestionBankCubit(repo, schedule: FakeBankScheduler().schedule),
    );
    repo.listResult = Success(
      BankPage(
        total: 3,
        page: 2,
        pageSize: 2,
        rows: bankPage.rows.take(1).toList(),
      ),
    );
    await tester.ensureVisible(find.byTooltip('Next page'));
    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(repo.calls.last.$2, 2);
    expect(
      find.text('3\u20133 of 3'),
      findsOneWidget,
    );
  });
  for (final (button, path) in [
    ('New question', '/teacher/questions/new'),
    ('Import', '/teacher/questions/import'),
  ]) {
    testWidgets('QB-06: $button navigates', (tester) async {
      final router = await pumpBank(
        tester,
        QuestionBankCubit(
          FakeBankRepository(),
          schedule: FakeBankScheduler().schedule,
        ),
      );
      await tester.tap(find.text(button));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, path);
    });
  }
  testWidgets('QB-06: empty and failed states are explicit', (tester) async {
    final repo = FakeBankRepository()
      ..listResult = const Failure(AppError('network'));
    final cubit = QuestionBankCubit(
      repo,
      schedule: FakeBankScheduler().schedule,
    );
    await pumpBank(tester, cubit);
    expect(find.text('Retry'), findsOneWidget);
    repo.listResult = Success(
      BankPage(total: 0, page: 1, pageSize: 25, rows: const []),
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No questions found.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
