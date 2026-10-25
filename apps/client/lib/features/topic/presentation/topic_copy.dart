import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/presentation/learning_copy.dart';

abstract final class TopicCopy {
  static const title = 'Topic';
  static const video = 'Video';
  static const notes = 'Notes';
  static const watchVideoFirst = 'Watch the video first.';
  static const openNotesFirst = 'Open the notes first.';

  static String videoProgress(int durationS, int pct, String? subtopicTitle) =>
      [
        ?subtopicTitle,
        '${durationS ~/ 60}:${(durationS % 60).toString().padLeft(2, '0')}',
        '$pct%',
      ].join(' \u00b7 ');
  static const practice = 'Practice';
  static const quiz = 'Quiz';
  static const startQuiz = 'Start quiz';
  static const resumeQuiz = 'Resume quiz';
  static const passed = 'Passed';
  static const backButton = 'Back to course';
  static const errorTitle = "Couldn't load topic";

  static String practiceProgress(int count, int min) =>
      '$count of $min practice questions done';

  static String practiceNeeded(int remaining) =>
      'Answer $remaining more practice questions to unlock the quiz.';

  static String cooldown(String localTime) =>
      'You can retake the quiz after $localTime.';

  static String bestScore(double score) {
    final value = score == score.truncateToDouble() ? score.toInt() : score;
    return 'Best score $value%';
  }

  static String errorBody(String code) => code == ErrorCodes.network
      ? LearningCopy.networkBody
      : LearningCopy.genericBody;
}
