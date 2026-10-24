import 'package:sat_east_client/core/errors/error_codes.dart';

String importErrorCopy(String code) => switch (code) {
  'unsupported' => 'Import works in the web app.',
  ErrorCodes.invalidInput => "This file isn't a JSON array of questions.",
  ErrorCodes.forbidden => 'Only the teacher can import questions.',
  _ => "Couldn't import. Check your connection and try again.",
};

String importProblemCopy(String problem) {
  final parts = problem.split(':');
  final detail = parts.skip(1).join(':');
  return switch (parts.first) {
    'missing' => 'Missing or invalid $detail.',
    'bad_enum' => 'Unknown $detail value.',
    'unknown_course' => 'Unknown course: $detail.',
    'unknown_topic' => 'Topic was not found in the first course.',
    'unknown_subtopic' => 'Subtopic was not found uniquely in the topic.',
    'unknown_skill' => 'Unknown skill: $detail.',
    'mcq_choices' => 'Use 2 to 5 choices with unique labels A to E.',
    'key_not_in_choices' => 'The key must name one of the choices.',
    'spr_has_choices' => 'An SPR question cannot have choices.',
    'spr_key' => 'Use parseable accepted answers and a non-negative tolerance.',
    'duplicate_ref' => 'This reference appears more than once in the file.',
    'too_long' => '$detail is too long.',
    'bad_status_change' => 'This status change is not allowed.',
    'too_many_rows' => 'The file exceeds the server import limit.',
    _ => 'This row needs correction.',
  };
}
