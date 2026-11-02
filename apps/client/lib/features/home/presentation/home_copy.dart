import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/presentation/learning_copy.dart';

abstract final class HomeCopy {
  static const continueEyebrow = 'Continue where you left off';
  static const startHere = 'Start here';
  static const continueButton = 'Continue';
  static const openTopic = 'Open topic';
  static const openContents = 'Open contents';
  static const activate = 'Enter activation code';
  static const browseCourses = 'Browse courses';
  static const expired = 'Your access has ended. Your progress is saved.';
  static const notEnrolled = "You're not in a course yet";
  static const errorTitle = "Couldn't load your home";
  static const video = 'Video';
  static const notes = 'Notes';
  static const practice = 'Practice';
  static const homework = 'Homework';
  static const quiz = 'Quiz';
  static const watchVideo = 'Watch the lesson video';
  static const readNotes = 'Read the notes';
  static const takeQuiz = 'Take the quiz';
  static const finishQuiz = 'Finish your quiz';
  static const homeworkStart = 'Start your homework';

  static String greeting(String name, {bool firstRun = false}) {
    final prefix = firstRun ? 'Welcome' : 'Hi';
    return name.isEmpty ? prefix : '$prefix, $name';
  }

  static String subtitle(String course, String unit) =>
      unit.isEmpty ? course : '$course \u00b7 $unit';
  static String topicTitle(String sortLabel, String title) =>
      sortLabel.isEmpty ? title : '$sortLabel $title';
  static String step(int index, String name) => 'Step $index of 5 \u00b7 $name';
  static String startTopic(String sortLabel) => 'Start topic $sortLabel';
  static String practiceCount(int count, int min) =>
      '$count of $min practice questions';
  static String homeworkProgress(int answered, int total) =>
      '$answered answered, ${total - answered} to go';
  static String quizCooldown(String time) => 'Quiz opens again at $time';
  static String progress(int passed, int total) =>
      '$passed of $total topics passed';
  static String expiry(String course, int days, String date) =>
      'Your $course access ends in $days '
      '${days == 1 ? 'day' : 'days'}, on $date.';
  static String finished(String course) => 'You finished $course';
  static String errorBody(String code) => code == ErrorCodes.network
      ? LearningCopy.networkBody
      : LearningCopy.genericBody;
}
