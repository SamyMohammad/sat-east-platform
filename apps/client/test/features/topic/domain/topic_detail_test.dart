import 'package:flutter_test/flutter_test.dart';

import 'package:sat_east_client/core/video/video_provider.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_detail.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_video.dart';

void main() {
  for (final hasVideos in [false, true]) {
    for (final done in [false, true]) {
      test('LRN-02: video gate videos=$hasVideos done=$done', () {
        final topic = TopicDetail(
          id: 't',
          title: 'Topic',
          sortLabel: '1',
          status: TopicStatus.open,
          practiceCount: 0,
          practiceMin: 10,
          quiz: const QuizAvailable(),
          videoDone: done,
          videos: hasVideos
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
        );
        expect(topic.notesLockedByVideo, hasVideos && !done);
        expect(topic.practiceLockedByVideo, hasVideos && !done);
      });
    }
  }
}
