import 'package:sat_east_client/core/errors/error_codes.dart';

String bankErrorCopy(String code) => code == ErrorCodes.forbidden
    ? 'Only the teacher can view the question bank.'
    : "Couldn't load questions. Check your connection and try again.";
String bankValueLabel(String value) => switch (value) {
  'draft' => 'Draft',
  'solved' => 'Solved',
  'needs_review' => 'Needs review',
  'approved' => 'Approved',
  'published' => 'Published',
  'retired' => 'Retired',
  'practice' => 'Practice',
  'quiz' => 'Quiz',
  'mock_reserve' => 'Mock reserve',
  'mcq' => 'MCQ',
  'spr' => 'SPR',
  _ => value,
};
