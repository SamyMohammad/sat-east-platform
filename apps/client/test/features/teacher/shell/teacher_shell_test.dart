import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/teacher/shell/teacher_shell.dart';

void main() {
  for (final width in [360.0, 1023.0, 1024.0, 1280.0]) {
    testWidgets('ADM-01: teacher shell navigation at $width', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 800);
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: '/teacher/courses/c1',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Text('Student app')),
          GoRoute(path: '/teacher', builder: (_, _) => const TeacherShell()),
          GoRoute(
            path: '/teacher/questions/import',
            builder: (_, _) => const TeacherShell(child: Text('Import body')),
          ),
          GoRoute(
            path: '/teacher/settings',
            builder: (_, _) => const TeacherShell(child: Text('Settings body')),
          ),
          GoRoute(
            path: '/teacher/courses/:courseId',
            builder: (_, _) => const TeacherShell(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pumpAndSettle();
      expect(find.text('Coming in the next step.'), findsOneWidget);
      if (width < 1024) {
        expect(find.text('Back to app'), findsNothing);
        await tester.tap(find.byTooltip('Open navigation menu'));
        await tester.pumpAndSettle();
        expect(find.byType(Drawer), findsOneWidget);
      } else {
        expect(find.byType(Drawer), findsNothing);
        expect(find.byTooltip('Open navigation menu'), findsNothing);
      }
      expect(find.text('Teacher area'), findsWidgets);
      final settings = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Settings'),
      );
      expect(settings.enabled, isTrue);
      expect(settings.onTap, isNotNull);
      expect(find.byTooltip('Coming soon'), findsNothing);
      await tester.tap(find.widgetWithText(ListTile, 'Settings'));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/teacher/settings',
      );
      if (width < 1024) {
        await tester.tap(find.byTooltip('Open navigation menu'));
        await tester.pumpAndSettle();
      }
      expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'Settings'))
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'Course builder'))
            .selected,
        isFalse,
      );
      await tester.tap(find.widgetWithText(ListTile, 'Questions'));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/teacher/questions/import',
      );
      if (width < 1024) {
        await tester.tap(find.byTooltip('Open navigation menu'));
        await tester.pumpAndSettle();
      }
      expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'Questions'))
            .selected,
        isTrue,
      );
      await tester.tap(find.widgetWithText(ListTile, 'Course builder'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/teacher');
      if (width < 1024) {
        await tester.tap(find.byTooltip('Open navigation menu'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Back to app'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
