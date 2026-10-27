import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/auth/domain/entities/my_profile.dart';
import 'package:sat_east_client/features/notes/presentation/cubit/notes_viewer_cubit.dart';
import 'package:sat_east_client/features/notes/presentation/screens/notes_viewer_screen.dart';
import 'package:sat_east_client/features/notes/presentation/widgets/notes_page_watermark.dart';

import '../notes_fixtures.dart';

void main() {
  testWidgets('L-3: retry loads the PDF and mark failure keeps it visible', (
    tester,
  ) async {
    final auth = MockNotesAuth();
    when(auth.getMyProfile).thenAnswer(
      (_) async =>
          const Success(MyProfile(fullName: 'Sara', email: 'sara@example.com')),
    );
    final pendingMark = Completer<Result<void>>();
    final repo = FakeNotesRepository()
      ..downloadResult = const Failure(AppError('network'))
      ..pendingMark = pendingMark.future;
    final cubit = NotesViewerCubit(
      repo,
      auth,
      () => DateTime.utc(2026, 10, 27),
    );
    getIt.registerFactory<NotesViewerCubit>(() => cubit);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await getIt.unregister<NotesViewerCubit>();
    });
    var renders = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: NotesViewerScreen(
            topicId: 't1',
            assetId: 'a1',
            documentBuilder: (_, bytes, overlay) {
              renders++;
              return const Text('Memory PDF');
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    repo.downloadResult = Success(Uint8List.fromList([1]));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Memory PDF'), findsOneWidget);
    pendingMark.complete(const Failure(AppError('network')));
    await tester.pumpAndSettle();
    expect(find.text('Memory PDF'), findsOneWidget);
    expect(
      find.text(
        "Your reading progress couldn't be saved. "
        'Reopen the notes to try again.',
      ),
      findsOneWidget,
    );
    expect(renders, 1);
  });
  for (final width in [360.0, 1280.0]) {
    testWidgets('SEC-02: every fake page has identity overlay at $width', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 1000);
      addTearDown(tester.view.reset);
      final auth = MockNotesAuth();
      when(auth.getMyProfile).thenAnswer(
        (_) async => const Success(
          MyProfile(
            fullName: 'Sara',
            email: 'sara@example.com',
          ),
        ),
      );
      final cubit = NotesViewerCubit(
        FakeNotesRepository(),
        auth,
        () => DateTime.utc(2026, 10, 27),
      );
      getIt.registerFactory<NotesViewerCubit>(() => cubit);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await getIt.unregister<NotesViewerCubit>();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: NotesViewerScreen(
              topicId: 't1',
              assetId: 'a1',
              documentBuilder: (_, bytes, overlay) => ListView(
                children: [
                  for (var page = 0; page < 2; page++)
                    SizedBox(
                      height: 400,
                      child: Stack(
                        children: [Positioned.fill(child: overlay())],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NotesPageWatermark), findsNWidgets(2));
      for (final page in find.byType(NotesPageWatermark).evaluate()) {
        final texts = find.descendant(
          of: find.byWidget(page.widget),
          matching: find.byType(Text),
        );
        expect(texts, findsWidgets);
        final text = tester.widget<Text>(texts.first);
        expect(
          text.data,
          'Sara \u00b7 sara \u00b7 2026-10-27',
        );
        expect(text.textDirection, TextDirection.ltr);
        expect(text.style?.color?.a, closeTo(0.25, 0.005));
      }
      expect(find.byTooltip('Download'), findsNothing);
      expect(find.byTooltip('Print'), findsNothing);
      expect(find.byTooltip('Share'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
