import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/video/video_provider.dart';
import 'package:sat_east_client/features/home/domain/entities/current_step.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_detail.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_homework.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_note.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_video.dart';

TopicVideo video(String id, int pct) => TopicVideo(
  assetId: id,
  title: id,
  durationS: 100,
  provider: VideoProvider.youtube,
  pct: pct,
  lastPositionS: pct,
);

TopicDetail topic({
  List<TopicVideo> videos = const [],
  bool videoDone = true,
  List<TopicNote> notes = const [],
  bool notesDone = true,
  int count = 5,
  int min = 5,
  HomeworkState homework = HomeworkState.skipped,
}) => TopicDetail(
  id: 'topic-id',
  title: 'Linear equations',
  sortLabel: '1.2',
  status: TopicStatus.open,
  practiceCount: count,
  practiceMin: min,
  quiz: const QuizAvailable(),
  videos: videos,
  videoDone: videoDone,
  notes: notes,
  notesDone: notesDone,
  homework: TopicHomework(state: homework),
);

void main() {
  const note = TopicNote(assetId: 'note-id', title: 'Notes');
  test('LRN-07: no videos skips to notes', () {
    expect(
      currentStepOf(topic(videoDone: false, notes: [note], notesDone: false)),
      const NotesStep(note),
    );
  });
  test('LRN-07: unfinished video is the current step', () {
    final unfinished = video('second', 90);
    expect(
      currentStepOf(
        topic(
          videos: [video('first', 100), unfinished, video('third', 79)],
          videoDone: false,
        ),
      ),
      VideoStep(unfinished),
    );
    expect(
      currentStepOf(topic(videos: [unfinished], videoDone: false)).index,
      1,
    );
  });
  test('LRN-07: no notes skips to practice', () {
    expect(
      currentStepOf(topic(notesDone: false, count: 0)),
      const PracticeStep(0, 5),
    );
  });
  test('LRN-07: practice below min', () {
    final step = currentStepOf(topic(count: 4));
    expect(step, const PracticeStep(4, 5));
    expect(step.index, 3);
  });
  test('LRN-07: homework in progress', () {
    final step = currentStepOf(topic(homework: HomeworkState.inProgress));
    expect(
      step,
      const HomeworkStep(TopicHomework(state: HomeworkState.inProgress)),
    );
    expect(step.index, 4);
  });
  test('LRN-07: submitted and skipped homework go to quiz', () {
    for (final state in [HomeworkState.submitted, HomeworkState.skipped]) {
      final step = currentStepOf(topic(homework: state));
      expect(step, const QuizStep(QuizAvailable()));
      expect(step.index, 5);
    }
  });
  test('LRN-07: video falls back to first when all are fully watched', () {
    final first = video('first', 100);
    expect(
      currentStepOf(
        topic(videos: [first, video('second', 100)], videoDone: false),
      ),
      VideoStep(first),
    );
  });
  test('LRN-07: notes use first asset and index two', () {
    final step = currentStepOf(topic(notes: [note], notesDone: false));
    expect(step, const NotesStep(note));
    expect(step.index, 2);
  });
  test('LRN-07: available homework is the current step', () {
    expect(
      currentStepOf(topic(homework: HomeworkState.available)),
      const HomeworkStep(TopicHomework(state: HomeworkState.available)),
    );
  });
}
