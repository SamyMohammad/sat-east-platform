import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/design_gallery/presentation/gallery_screen.dart';

void main() {
  final destinations = [
    (AppRoutes.home, 'Home'),
    (AppRoutes.courses, 'Courses'),
    (AppRoutes.skills, 'Skills'),
    (AppRoutes.mockExams, 'Mock exams'),
    (AppRoutes.profile, 'Profile'),
  ];

  for (final width in [360.0, 768.0, 1280.0]) {
    for (var index = 0; index < destinations.length; index++) {
      final (path, label) = destinations[index];
      testWidgets('F-4: direct $path link selects $label at $width', (
        tester,
      ) async {
        _viewport(tester, width);
        final router = createRouter(initialLocation: path);
        try {
          await _pumpRouter(tester, router);
          expect(router.routeInformationProvider.value.uri.path, path);
          expect(_selectedIndex(tester), index);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          router.dispose();
        }
      });
    }

    testWidgets('F-4: navigation taps change production routes at $width', (
      tester,
    ) async {
      _viewport(tester, width);
      final router = createRouter();
      try {
        await _pumpRouter(tester, router);
        for (var index = 0; index < destinations.length; index++) {
          final (path, label) = destinations[index];
          final target = find.descendant(
            of: _navigationFinder(),
            matching: find.text(label),
          );
          await tester.ensureVisible(target);
          await tester.tap(target);
          await tester.pumpAndSettle();
          expect(router.routeInformationProvider.value.uri.path, path);
          expect(_selectedIndex(tester), index);
        }
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
      }
    });
  }

  testWidgets('F-4: resize preserves the production deep link and selection', (
    tester,
  ) async {
    _viewport(tester, 360);
    final router = createRouter(initialLocation: AppRoutes.mockExams);
    try {
      await _pumpRouter(tester, router);
      for (final width in [768.0, 1280.0, 360.0]) {
        tester.view.physicalSize = Size(width, 800);
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          AppRoutes.mockExams,
        );
        expect(_selectedIndex(tester), 3);
        expect(tester.takeException(), isNull);
      }
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
    }
  });

  testWidgets('F-4: /gallery is not routed when includeGallery is false', (
    tester,
  ) async {
    _viewport(tester, 1280);
    final router = createRouter(
      initialLocation: AppRoutes.gallery,
      includeGallery: false,
    );
    try {
      await _pumpRouter(tester, router);
      expect(find.byType(GalleryScreen), findsNothing);
      // go_router shows its error page; no exception may escape.
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
    }
  });

  testWidgets('F-4: /gallery shows the gallery when includeGallery is true', (
    tester,
  ) async {
    _viewport(tester, 1280);
    final router = createRouter(
      initialLocation: AppRoutes.gallery,
      includeGallery: true,
    );
    try {
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(GalleryScreen), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
    }
  });
}

void _viewport(WidgetTester tester, double width) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _pumpRouter(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(
    MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
  await tester.pumpAndSettle();
}

Finder _navigationFinder() => find.byWidgetPredicate(
  (widget) =>
      widget is NavigationBar ||
      widget is NavigationRail ||
      widget is NavigationDrawer,
);

int? _selectedIndex(WidgetTester tester) =>
    switch (tester.widget<Widget>(_navigationFinder())) {
      NavigationBar(:final selectedIndex) => selectedIndex,
      NavigationRail(:final selectedIndex) => selectedIndex,
      NavigationDrawer(:final selectedIndex) => selectedIndex,
      _ => throw StateError('Expected native navigation'),
    };
