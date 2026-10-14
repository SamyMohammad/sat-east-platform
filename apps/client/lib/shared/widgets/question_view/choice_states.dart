import 'package:sat_east_client/shared/widgets/choice_tile.dart';
import 'package:sat_east_client/shared/widgets/question_view/answer_state.dart';
import 'package:sat_east_client/shared/widgets/question_view/practice_feedback.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view_mode.dart';

typedef ChoiceLook = ({ChoiceTileState state, String? statusLabel});

const _firstTryLabel = '1st try';
const _yourAnswerLabel = 'Your answer';

ChoiceLook _look(ChoiceTileState state, [String? statusLabel]) =>
    (state: state, statusLabel: statusLabel);

/// Maps one choice to its tile look for the current mode and feedback.
ChoiceLook choiceLookFor(
  String label,
  AnswerState answer,
  QuestionViewMode mode,
) {
  final selected = answer.selected == label;
  final working = _look(
    selected
        ? ChoiceTileState.selected
        : answer.eliminated.contains(label)
        ? ChoiceTileState.eliminated
        : ChoiceTileState.idle,
  );
  final other = _look(ChoiceTileState.reviewOther);
  final firstTry = _look(ChoiceTileState.incorrect, _firstTryLabel);

  return switch (mode) {
    HomeworkMode() => working,
    PracticeMode(:final feedback) => switch (feedback) {
      Idle() => working,
      Checking() => _look(
        selected ? ChoiceTileState.selected : ChoiceTileState.disabled,
      ),
      FirstMiss(:final missed) =>
        missed == label ? _look(ChoiceTileState.incorrect) : working,
      Correct(firstTry: final tried) =>
        selected
            ? _look(ChoiceTileState.correct)
            : tried == label
            ? firstTry
            : other,
      Revealed(:final key, firstTry: final tried) =>
        key is McqAnswerKey && key.label == label
            ? _look(ChoiceTileState.correctAnswer)
            : tried == label
            ? firstTry
            : selected
            ? _look(ChoiceTileState.incorrect, _yourAnswerLabel)
            : other,
    },
  };
}
