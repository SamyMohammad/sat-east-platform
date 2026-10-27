import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/design_gallery/presentation/gallery_entries.dart';
import 'package:sat_east_client/shared/widgets/question_view/practice_feedback.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view_mode.dart';

const _expectedIds = [
  'practice-idle',
  'practice-checking',
  'practice-first-miss',
  'practice-correct',
  'practice-revealed',
  'practice-revealed-spr',
  'homework-saved',
  'homework-saving',
  'homework-offline',
  'homework-failed',
  'homework-navigator',
  'quiz',
  'quiz-warning',
  'quiz-timer-hidden',
  'quiz-navigator',
  'quiz-submit',
  'quiz-time-up',
];

const _overlayIds = {
  'homework-navigator',
  'quiz-navigator',
  'quiz-submit',
  'quiz-time-up',
};

void main() {
  test('F-4: gallery has 17 entries in table order with unique ids', () {
    final ids = galleryEntries.map((e) => e.id).toList();
    expect(ids, _expectedIds);
    expect(ids.toSet().length, ids.length);
  });

  test('F-4: galleryEntryById returns the matching entry', () {
    for (final entry in galleryEntries) {
      expect(galleryEntryById(entry.id), same(entry));
    }
  });

  test('F-4: galleryEntryById falls back to the first entry', () {
    for (final id in [null, '', 'nope']) {
      expect(galleryEntryById(id), same(galleryEntries.first));
    }
  });

  test('F-4: only the four overlay entries have openOverlay', () {
    final withOverlay = galleryEntries
        .where((e) => e.openOverlay != null)
        .map((e) => e.id)
        .toSet();
    expect(withOverlay, _overlayIds);
  });

  testWidgets(
    'F-4: practice-revealed explanation contains the worked solution',
    (
      tester,
    ) async {
      _viewport(tester, 1280);
      await _pump(tester, galleryEntryById('practice-revealed'));
      final view = tester.widget<QuestionView>(find.byType(QuestionView));
      final feedback = (view.mode as PracticeMode).feedback as Revealed;
      expect(feedback.explanationMd, contains('Add 7 to both sides'));
    },
  );

  for (final width in [360.0, 1280.0]) {
    for (final id in _expectedIds) {
      testWidgets('F-4: $id renders without exceptions at $width', (
        tester,
      ) async {
        _viewport(tester, width);
        final entry = galleryEntryById(id);
        final context = await _pump(tester, entry);
        entry.openOverlay?.call(context);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(tester.takeException(), isNull);
        expect(find.byType(QuestionView), findsOneWidget);
      });
    }
  }
}

Future<BuildContext> _pump(WidgetTester tester, GalleryEntry entry) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            captured = context;
            return entry.builder(context);
          },
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  return captured;
}

void _viewport(WidgetTester tester, double width) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}
