import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/design_gallery/presentation/gallery_entries.dart';
import 'package:sat_east_client/features/design_gallery/presentation/gallery_screen.dart';
import 'package:sat_east_client/shared/widgets/booklet_dialog.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/exam_bar.dart';

void main() {
  for (final width in [360.0, 1280.0]) {
    group('F-4: gallery screen at $width', () {
      testWidgets('F-4: /gallery shows the first entry and the title', (
        tester,
      ) async {
        _viewport(tester, width);
        final router = createRouter(
          initialLocation: AppRoutes.gallery,
          includeGallery: true,
        );
        try {
          await _pumpGallery(tester, router);
          expect(find.byType(GalleryScreen), findsOneWidget);
          expect(find.text('Design gallery'), findsOneWidget);
          expect(find.text('Practice · Idle'), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          await _dispose(tester, router);
        }
      });

      testWidgets('F-4: choosing Quiz · Question updates the location', (
        tester,
      ) async {
        _viewport(tester, width);
        final router = createRouter(
          initialLocation: AppRoutes.gallery,
          includeGallery: true,
        );
        try {
          await _pumpGallery(tester, router);
          expect(find.byType(ExamBar), findsNothing);

          await tester.tap(find.byType(DropdownButton<String>));
          await _pumpBounded(tester);
          await tester.tap(find.text('Quiz · Question').last);
          await _pumpBounded(tester);

          expect(
            router.routeInformationProvider.value.uri.toString(),
            galleryLocation('quiz'),
          );
          expect(find.byType(ExamBar), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          await _dispose(tester, router);
        }
      });

      testWidgets('F-4: next and previous move one entry', (tester) async {
        _viewport(tester, width);
        final router = createRouter(
          initialLocation: galleryLocation(galleryEntries[1].id),
          includeGallery: true,
        );
        try {
          await _pumpGallery(tester, router);

          await tester.tap(find.byTooltip('Next entry'));
          await _pumpBounded(tester);
          expect(_location(router), galleryLocation(galleryEntries[2].id));

          await tester.tap(find.byTooltip('Previous entry'));
          await _pumpBounded(tester);
          expect(_location(router), galleryLocation(galleryEntries[1].id));

          await tester.tap(find.byTooltip('Previous entry'));
          await _pumpBounded(tester);
          expect(_location(router), galleryLocation(galleryEntries[0].id));
          expect(tester.takeException(), isNull);
        } finally {
          await _dispose(tester, router);
        }
      });

      testWidgets('F-4: previous is disabled on the first entry', (
        tester,
      ) async {
        _viewport(tester, width);
        final router = createRouter(
          initialLocation: galleryLocation(galleryEntries.first.id),
          includeGallery: true,
        );
        try {
          await _pumpGallery(tester, router);
          expect(_button(tester, Icons.chevron_left).onPressed, isNull);
          expect(_button(tester, Icons.chevron_right).onPressed, isNotNull);
        } finally {
          await _dispose(tester, router);
        }
      });

      testWidgets('F-4: next is disabled on the last entry', (tester) async {
        _viewport(tester, width);
        final router = createRouter(
          initialLocation: galleryLocation(galleryEntries.last.id),
          includeGallery: true,
        );
        try {
          await _pumpGallery(tester, router);
          expect(_button(tester, Icons.chevron_right).onPressed, isNull);
          expect(_button(tester, Icons.chevron_left).onPressed, isNotNull);
        } finally {
          await _dispose(tester, router);
        }
      });

      testWidgets(
        'F-4: quiz-submit opens the dialog and Reopen shows it again',
        (
          tester,
        ) async {
          _viewport(tester, width);
          final router = createRouter(
            initialLocation: galleryLocation('quiz-submit'),
            includeGallery: true,
          );
          try {
            await tester.pumpWidget(
              MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
            );
            await tester.pumpAndSettle();
            expect(find.text('Submit quiz?'), findsOneWidget);

            await tester.tap(find.text('Keep working'));
            await tester.pumpAndSettle();
            expect(find.text('Submit quiz?'), findsNothing);

            await tester.tap(find.text('Reopen'));
            await tester.pumpAndSettle();
            expect(find.text('Submit quiz?'), findsOneWidget);
            expect(tester.takeException(), isNull);
          } finally {
            await _dispose(tester, router);
          }
        },
      );

      testWidgets('F-4: Reopen is absent on an entry without an overlay', (
        tester,
      ) async {
        _viewport(tester, width);
        final router = createRouter(
          initialLocation: galleryLocation('quiz'),
          includeGallery: true,
        );
        try {
          await _pumpGallery(tester, router);
          expect(find.text('Reopen'), findsNothing);
        } finally {
          await _dispose(tester, router);
        }
      });

      testWidgets('F-4: leaving an overlay entry closes its dialog', (
        tester,
      ) async {
        _viewport(tester, width);
        final router = createRouter(
          initialLocation: galleryLocation('quiz-submit'),
          includeGallery: true,
        );
        try {
          await tester.pumpWidget(
            MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
          );
          await tester.pumpAndSettle();
          expect(find.byType(BookletDialog), findsOneWidget);

          router.go(galleryLocation('quiz'));
          await tester.pumpAndSettle();

          expect(find.byType(BookletDialog), findsNothing);
          expect(find.byType(ExamBar), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          await _dispose(tester, router);
        }
      });

      testWidgets('F-4: choosing quiz from quiz-submit leaves no dialog', (
        tester,
      ) async {
        _viewport(tester, width);
        final router = createRouter(
          initialLocation: galleryLocation('quiz-submit'),
          includeGallery: true,
        );
        try {
          await tester.pumpWidget(
            MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
          );
          await tester.pumpAndSettle();
          expect(find.byType(BookletDialog), findsOneWidget);

          // A modal barrier blocks the AppBar; dismiss it as a user would.
          await tester.tap(find.text('Keep working'));
          await tester.pumpAndSettle();
          await tester.tap(find.byType(DropdownButton<String>));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Quiz · Question').last);
          await tester.pumpAndSettle();

          expect(_location(router), galleryLocation('quiz'));
          expect(find.byType(BookletDialog), findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          await _dispose(tester, router);
        }
      });

      testWidgets('F-4: unknown entry id falls back to the first entry', (
        tester,
      ) async {
        _viewport(tester, width);
        final router = createRouter(
          initialLocation: galleryLocation('nope'),
          includeGallery: true,
        );
        try {
          await _pumpGallery(tester, router);
          expect(find.text('Practice · Idle'), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          await _dispose(tester, router);
        }
      });
    });
  }

  testWidgets('F-4: the AppBar does not overflow at 360', (tester) async {
    _viewport(tester, 360);
    // quiz-submit shows the widest action row (includes Reopen).
    final router = createRouter(
      initialLocation: galleryLocation('quiz-submit'),
      includeGallery: true,
    );
    try {
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pumpAndSettle();
      expect(find.text('Reopen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await _dispose(tester, router);
    }
  });

  testWidgets('F-4: the AppBar does not overflow at 360 with a long label', (
    tester,
  ) async {
    _viewport(tester, 360);
    final router = createRouter(
      initialLocation: galleryLocation('practice-revealed-spr'),
      includeGallery: true,
    );
    try {
      await _pumpGallery(tester, router);
      expect(tester.takeException(), isNull);
    } finally {
      await _dispose(tester, router);
    }
  });
}

void _viewport(WidgetTester tester, double width) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

/// Bounded pumps: spinner entries never settle.
Future<void> _pumpBounded(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _pumpGallery(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(
    MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
  await _pumpBounded(tester);
}

Future<void> _dispose(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(const SizedBox.shrink());
  router.dispose();
}

String _location(GoRouter router) =>
    router.routeInformationProvider.value.uri.toString();

IconButton _button(WidgetTester tester, IconData icon) =>
    tester.widget<IconButton>(find.widgetWithIcon(IconButton, icon));
