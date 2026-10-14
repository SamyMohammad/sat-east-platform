import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/shared/widgets/choice_tile.dart';
import 'package:sat_east_client/shared/widgets/question_view/answer_state.dart';
import 'package:sat_east_client/shared/widgets/question_view/choice_states.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_data.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view_mode.dart';

/// MCQ choices for `QuestionView`. When [interactive] is false every tile
/// gets null callbacks, so nothing can be selected, crossed out or restored.
class ChoiceList extends StatelessWidget {
  const ChoiceList({
    required this.choices,
    required this.answer,
    required this.mode,
    required this.interactive,
    super.key,
    this.onSelect,
    this.onEliminate,
    this.onRestore,
  });

  final List<ChoiceData> choices;
  final AnswerState answer;
  final QuestionViewMode mode;
  final bool interactive;
  final ValueChanged<String>? onSelect;
  final ValueChanged<String>? onEliminate;
  final ValueChanged<String>? onRestore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BookletSpace.s3,
      children: [
        for (final choice in choices) _tile(choice),
      ],
    );
  }

  Widget _tile(ChoiceData choice) {
    final look = choiceLookFor(choice.label, answer, mode);
    final label = choice.label;
    return ChoiceTile(
      key: ValueKey('choice-$label'),
      letter: label,
      content: choice.md,
      state: look.state,
      statusLabel: look.statusLabel,
      onSelect: interactive && onSelect != null ? () => onSelect!(label) : null,
      onEliminate: interactive && onEliminate != null
          ? () => onEliminate!(label)
          : null,
      onRestore: interactive && onRestore != null
          ? () => onRestore!(label)
          : null,
    );
  }
}
