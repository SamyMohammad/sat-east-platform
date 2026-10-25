import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/core/video/video_provider.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_detail.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_note.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_video.dart';
import 'package:sat_east_client/features/topic/presentation/topic_copy.dart';
import 'package:sat_east_client/features/topic/presentation/widgets/topic_content.dart';

void main() {
  TopicDetail topic({bool videos = true, bool done = false}) => TopicDetail(
    id: 't',
    title: 'Topic',
    sortLabel: '1',
    status: TopicStatus.open,
    practiceCount: 0,
    practiceMin: 10,
    quiz: const QuizAvailable(),
    notes: const [TopicNote(assetId: 'n', title: 'Handout')],
    notesDone: false,
    videos: videos
        ? const [
            TopicVideo(
              assetId: 'v',
              title: 'Lesson',
              durationS: 600,
              provider: VideoProvider.r2Hls,
              pct: 40,
              lastPositionS: 120,
            ),
          ]
        : const [],
    videoDone: done,
  );

  Future<void> pump(
    WidgetTester tester,
    TopicDetail detail, {
    VoidCallback? open,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: TopicContent(
            topic: detail,
            onPractice: () {},
            onQuiz: () {},
            onNotes: (_) => open?.call(),
            onVideo: (_) => open?.call(),
          ),
        ),
      ),
    ),
  );

  testWidgets('LRN-02: Video precedes Notes and shows duration and progress', (
    tester,
  ) async {
    var opened = false;
    await pump(tester, topic(), open: () => opened = true);
    expect(
      tester.getTopLeft(find.text('Video')).dy,
      lessThan(tester.getTopLeft(find.text('Notes')).dy),
    );
    expect(find.textContaining('10:00'), findsOneWidget);
    expect(find.textContaining('40%'), findsOneWidget);
    await tester.tap(find.text('Lesson'));
    expect(opened, isTrue);
  });
  testWidgets(
    'LRN-02: video gate disables notes and practice with priority copy',
    (tester) async {
      var opened = false;
      await pump(tester, topic(), open: () => opened = true);
      expect(find.text(TopicCopy.watchVideoFirst), findsNWidgets(2));
      expect(find.text(TopicCopy.openNotesFirst), findsNothing);
      final note = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('Handout'),
          matching: find.byType(ListTile),
        ),
      );
      expect(note.onTap, isNull);
      expect(note.enabled, isFalse);
      await tester.tap(find.text('Handout'));
      expect(opened, isFalse);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Practice'),
      );
      expect(button.onPressed, isNull);
    },
  );
  testWidgets('LRN-02: completed video shows check and restores notes gate', (
    tester,
  ) async {
    await pump(tester, topic(done: true));
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    expect(find.text(TopicCopy.openNotesFirst), findsOneWidget);
  });
  testWidgets('LRN-02: topic without videos has no Video step', (tester) async {
    await pump(tester, topic(videos: false));
    expect(find.text('Video'), findsNothing);
    expect(find.text(TopicCopy.openNotesFirst), findsOneWidget);
  });
}
