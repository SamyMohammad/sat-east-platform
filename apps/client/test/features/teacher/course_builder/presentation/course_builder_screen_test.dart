import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/teacher/course_builder/presentation/cubit/course_builder_cubit.dart';
import 'package:sat_east_client/features/teacher/course_builder/presentation/screens/course_builder_screen.dart';
import 'package:sat_east_client/features/teacher/shell/teacher_shell.dart';

import '../../review/review_fixtures.dart';
import '../builder_fixtures.dart';

Future<FakeBuilderRepository> pumpBuilder(
  WidgetTester tester, {
  double width = 1280,
  FakeBuilderRepository? repository,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1200);
  addTearDown(tester.view.reset);
  final repo = repository ?? FakeBuilderRepository();
  final cubit = CourseBuilderCubit(repo);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await cubit.close();
  });
  await cubit.load('c1');
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: TeacherShell(
        child: BlocProvider.value(
          value: cubit,
          child: const CourseBuilderView(courseId: 'c1'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

Future<void> openMenu(WidgetTester tester, String id) async {
  final menu = find.byKey(ValueKey('menu-$id'));
  await tester.ensureVisible(menu);
  await tester.tap(menu);
  await tester.pumpAndSettle();
}

void main() {
  setUp(registerReviewFakes);
  tearDown(unregisterReviewFakes);
  testWidgets('C-3: topic Notes menu opens its teacher manager', (
    tester,
  ) async {
    final cubit = CourseBuilderCubit(FakeBuilderRepository());
    addTearDown(cubit.close);
    await cubit.load('c1');
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => TeacherShell(
            child: BlocProvider.value(
              value: cubit,
              child: const CourseBuilderView(courseId: 'c1'),
            ),
          ),
        ),
        GoRoute(
          path: '/teacher/courses/c1/topics/t1/notes',
          builder: (_, _) => const Scaffold(body: Text('Notes manager')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
    await tester.pumpAndSettle();
    await openMenu(tester, 't1');
    await tester.tap(find.text('Notes\u2026'));
    await tester.pumpAndSettle();
    expect(find.text('Notes manager'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('C-2: topic Videos menu opens its teacher manager', (
    tester,
  ) async {
    final cubit = CourseBuilderCubit(FakeBuilderRepository());
    addTearDown(cubit.close);
    await cubit.load('c1');
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => TeacherShell(
            child: BlocProvider.value(
              value: cubit,
              child: const CourseBuilderView(courseId: 'c1'),
            ),
          ),
        ),
        GoRoute(
          path: '/teacher/courses/c1/topics/t1/videos',
          builder: (_, _) => const Scaffold(body: Text('Videos manager')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
    await tester.pumpAndSettle();
    await openMenu(tester, 't1');
    await tester.tap(find.text('Videos\u2026'));
    await tester.pumpAndSettle();
    expect(find.text('Videos manager'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final width in [360.0, 768.0, 1280.0]) {
    testWidgets('C-1: numbered tree fits $width', (tester) async {
      await pumpBuilder(tester, width: width);
      expect(find.text('1.1'), findsOneWidget);
      expect(find.text('1.1.1'), findsOneWidget);
      expect(find.text('Linear equations'), findsOneWidget);
      expect(find.text('Draft'), findsWidgets);
      expect(find.text('Published'), findsWidgets);
      for (final label in ['Draft', 'Published']) {
        final text = tester.widget<Text>(find.text(label).first);
        expect(text.maxLines, 1);
        expect(text.softWrap, isFalse);
      }
      expect(tester.takeException(), isNull);
    });
  }
  for (final (label, operation, parent) in [
    ('Add unit', 'unit', 'c1'),
    ('Add topic', 'topic', 'u1'),
    ('Add subtopic', 'subtopic', 't1'),
  ]) {
    testWidgets('C-1: $label submits entered title', (tester) async {
      final repo = await pumpBuilder(tester);
      final add = find.text(label).first;
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'New title');
      await tester.tap(find.widgetWithText(FilledButton, label));
      await tester.pumpAndSettle();
      expect(repo.calls.where((c) => c.$1 == operation).single.$2, {
        'id': null,
        'parent': parent,
        'title': 'New title',
      });
    });
  }
  testWidgets('C-1: a unit shows its subtopic count', (tester) async {
    await pumpBuilder(tester);
    expect(find.text('2 subtopics'), findsOneWidget);
  });
  for (final (kind, id, code, title) in [
    ('unit', 'u2', '2', 'Geometry'),
    ('topic', 't2', '1.2', 'Quadratics'),
    ('subtopic', 's1', '1.1.1', 'Basics'),
  ]) {
    testWidgets('C-1: deleting $kind requires confirmation', (tester) async {
      final repo = await pumpBuilder(tester);
      await openMenu(tester, id);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.text("Delete $code $title? This can't be undone."),
        findsOneWidget,
      );
      expect(repo.calls.where((call) => call.$1 == 'delete'), isEmpty);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(repo.calls.where((call) => call.$1 == 'delete'), isEmpty);

      await openMenu(tester, id);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      final call = repo.calls.where((call) => call.$1 == 'delete').single;
      expect(call.$2, equals({'kind': kind, 'id': id}));
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('C-1: unpublish does not ask publish confirmation', (
    tester,
  ) async {
    final repo = await pumpBuilder(tester);
    await openMenu(tester, 't2');
    await tester.tap(find.text('Unpublish'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(repo.calls.where((c) => c.$1 == 'flags').single.$2, {
      'id': 't2',
      'published': false,
      'preview': null,
    });
  });
  testWidgets('C-1: rename edits inline', (tester) async {
    final repo = await pumpBuilder(tester);
    await openMenu(tester, 't1');
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.enterText(find.byType(TextFormField), 'Renamed');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c.$1 == 'topic').single.$2, {
      'id': 't1',
      'parent': 'u1',
      'title': 'Renamed',
    });
  });
  testWidgets('C-1: move button submits new sibling order', (tester) async {
    final repo = await pumpBuilder(tester);
    await tester.tap(find.byKey(const ValueKey('move-down-t1')));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c.$1 == 'reorder').single.$2, {
      'kind': 'topic',
      'parent': 'u1',
      'ids': ['t2', 't1'],
    });
  });
  testWidgets('C-1: drag callback uses the already-adjusted destination', (
    tester,
  ) async {
    final repo = await pumpBuilder(tester);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('siblings-unit-c1')),
        matching: find.byType(Tooltip),
      ),
      findsNothing,
    );
    final list = tester.widget<ReorderableListView>(
      find.byKey(const ValueKey('siblings-topic-u1')),
    );
    list.onReorderItem!(0, 1);
    await tester.pumpAndSettle();
    final call = repo.calls.where((call) => call.$1 == 'reorder').single;
    expect(
      call.$2,
      equals({
        'kind': 'topic',
        'parent': 'u1',
        'ids': ['t2', 't1'],
      }),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
      tester.getCenter(
        find.byKey(const ValueKey('move-down-t1')),
      ),
    );
    await tester.pumpAndSettle();
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('C-1: in-use delete is disabled with a reason', (tester) async {
    final repo = await pumpBuilder(tester);
    await openMenu(tester, 't1');
    expect(find.text('In use'), findsOneWidget);
    final item = tester.widget<PopupMenuItem<String>>(
      find.ancestor(
        of: find.text('Delete'),
        matching: find.byType(PopupMenuItem<String>),
      ),
    );
    expect(item.enabled, isFalse);
    expect(repo.calls.where((c) => c.$1 == 'delete'), isEmpty);
  });
  testWidgets('C-1: publish requires confirmation', (tester) async {
    final repo = await pumpBuilder(tester);
    await tester.tap(find.byKey(const ValueKey('publish-t1')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Publish 1.1 Linear equations? '
        'Students on the path will see it.',
      ),
      findsOneWidget,
    );
    expect(repo.calls.where((c) => c.$1 == 'flags'), isEmpty);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c.$1 == 'flags'), isEmpty);
    await tester.tap(find.byKey(const ValueKey('publish-t1')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Publish'));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c.$1 == 'flags').single.$2, {
      'id': 't1',
      'published': true,
      'preview': null,
    });
  });
  testWidgets('C-1: free preview only changes its own flag', (tester) async {
    final repo = await pumpBuilder(tester);
    await tester.tap(find.byKey(const ValueKey('preview-t1')));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c.$1 == 'flags').single.$2, {
      'id': 't1',
      'published': null,
      'preview': true,
    });
  });
  for (final (code, message) in [
    (ErrorCodes.inUse, "This item is in use and can't be deleted."),
    (ErrorCodes.forbidden, 'Only the teacher can change the course.'),
    (
      ErrorCodes.invalidInput,
      "That change wasn't saved. Reload and try again.",
    ),
    (ErrorCodes.network, "Couldn't save. Check your connection and try again."),
  ]) {
    testWidgets('C-1: $code shows safe SnackBar copy', (tester) async {
      final repo = FakeBuilderRepository()
        ..mutation = Failure(AppError(code, 'secret raw text'));
      await pumpBuilder(tester, repository: repo);
      await tester.tap(find.byKey(const ValueKey('move-down-t1')));
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);
      expect(find.text('secret raw text'), findsNothing);
    });
  }
  testWidgets('C-1: failed load offers a working retry', (tester) async {
    final repo = FakeBuilderRepository()
      ..tree = const Failure(AppError(ErrorCodes.network));
    await pumpBuilder(tester, repository: repo);
    expect(find.text('Retry'), findsOneWidget);
    repo.tree = Success(builderTree);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Linear equations'), findsOneWidget);
  });
  testWidgets('C-1: empty course list explains empty state', (tester) async {
    await pumpBuilder(
      tester,
      repository: FakeBuilderRepository()..courses = const Success([]),
    );
    expect(find.text('No courses yet.'), findsOneWidget);
  });
  testWidgets('C-1: entry replaces URL and dropdown switches courses', (
    tester,
  ) async {
    final repo = FakeBuilderRepository();
    getIt.registerFactory<CourseBuilderCubit>(() => CourseBuilderCubit(repo));
    addTearDown(getIt.unregister<CourseBuilderCubit>);
    final router = GoRouter(
      initialLocation: '/teacher',
      routes: [
        GoRoute(
          path: '/teacher',
          builder: (_, _) => const TeacherShell(child: CourseBuilderScreen()),
        ),
        GoRoute(
          path: '/teacher/courses/:courseId',
          builder: (_, s) => TeacherShell(
            child: CourseBuilderScreen(courseId: s.pathParameters['courseId']),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/teacher/courses/c1',
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('EST Math').last);
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/teacher/courses/c2',
    );
    expect(
      repo.calls.where((call) => call.$1 == 'tree').map((call) => call.$2),
      contains(equals({'courseId': 'c2'})),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
