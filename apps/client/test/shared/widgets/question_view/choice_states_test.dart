import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/shared/widgets/choice_tile.dart';
import 'package:sat_east_client/shared/widgets/question_view/answer_state.dart';
import 'package:sat_east_client/shared/widgets/question_view/choice_states.dart';
import 'package:sat_east_client/shared/widgets/question_view/practice_feedback.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view_mode.dart';

PracticeMode practice(PracticeFeedback feedback) =>
    PracticeMode(feedback: feedback, rep: 1, repTarget: 3);

const homework = HomeworkMode(
  title: 'Homework 4.2',
  index: 0,
  total: 5,
  saveStatus: SaveStatus.saved,
);

void expectLook(
  ChoiceLook look,
  ChoiceTileState state, [
  String? statusLabel,
]) {
  expect(look.state, state);
  expect(look.statusLabel, statusLabel);
}

void main() {
  group('Idle', () {
    final mode = practice(const Idle());

    test('F-4: selected choice looks selected', () {
      expectLook(
        choiceLookFor('B', const AnswerState(selected: 'B'), mode),
        ChoiceTileState.selected,
      );
    });

    test('F-4: eliminated choice looks eliminated', () {
      expectLook(
        choiceLookFor('C', const AnswerState(eliminated: {'C'}), mode),
        ChoiceTileState.eliminated,
      );
    });

    test('F-4: other choice looks idle', () {
      expectLook(
        choiceLookFor('A', const AnswerState(selected: 'B'), mode),
        ChoiceTileState.idle,
      );
    });
  });

  group('Homework', () {
    test('F-4: selected choice looks selected', () {
      expectLook(
        choiceLookFor('B', const AnswerState(selected: 'B'), homework),
        ChoiceTileState.selected,
      );
    });

    test('F-4: eliminated choice looks eliminated', () {
      expectLook(
        choiceLookFor('C', const AnswerState(eliminated: {'C'}), homework),
        ChoiceTileState.eliminated,
      );
    });

    test('F-4: other choice looks idle', () {
      expectLook(
        choiceLookFor('A', const AnswerState(selected: 'B'), homework),
        ChoiceTileState.idle,
      );
    });
  });

  group('Quiz', () {
    const quiz = QuizMode(
      title: 'Quiz 4.2',
      index: 0,
      total: 5,
      remaining: Duration(minutes: 10),
      timeBudget: Duration(minutes: 18),
      warnAt: Duration(minutes: 5),
    );

    test('F-4: selected choice looks selected', () {
      expectLook(
        choiceLookFor('B', const AnswerState(selected: 'B'), quiz),
        ChoiceTileState.selected,
      );
    });

    test('F-4: eliminated choice looks eliminated', () {
      expectLook(
        choiceLookFor('C', const AnswerState(eliminated: {'C'}), quiz),
        ChoiceTileState.eliminated,
      );
    });

    test('F-4: other choice looks idle', () {
      expectLook(
        choiceLookFor('A', const AnswerState(selected: 'B'), quiz),
        ChoiceTileState.idle,
      );
    });
  });

  group('Checking', () {
    final mode = practice(const Checking());

    test('F-4: selected choice looks selected', () {
      expectLook(
        choiceLookFor('B', const AnswerState(selected: 'B'), mode),
        ChoiceTileState.selected,
      );
    });

    test('F-4: other choice looks disabled', () {
      expectLook(
        choiceLookFor('A', const AnswerState(selected: 'B'), mode),
        ChoiceTileState.disabled,
      );
    });
  });

  group('FirstMiss', () {
    final mode = practice(const FirstMiss(missed: 'B'));

    test('F-4: the missed choice looks incorrect', () {
      expectLook(
        choiceLookFor('B', const AnswerState(selected: 'B'), mode),
        ChoiceTileState.incorrect,
      );
    });

    test('F-4: the missed choice stays incorrect after reselecting', () {
      expectLook(
        choiceLookFor('B', const AnswerState(selected: 'C'), mode),
        ChoiceTileState.incorrect,
      );
    });

    test('F-4: a newly selected choice looks selected', () {
      expectLook(
        choiceLookFor('C', const AnswerState(selected: 'C'), mode),
        ChoiceTileState.selected,
      );
    });

    test('F-4: an eliminated choice looks eliminated', () {
      expectLook(
        choiceLookFor('D', const AnswerState(eliminated: {'D'}), mode),
        ChoiceTileState.eliminated,
      );
    });

    test('F-4: another choice looks idle', () {
      expectLook(
        choiceLookFor('A', const AnswerState(selected: 'C'), mode),
        ChoiceTileState.idle,
      );
    });
  });

  group('Correct', () {
    final mode = practice(const Correct(firstTry: 'B'));

    test('F-4: selected choice looks correct', () {
      expectLook(
        choiceLookFor('C', const AnswerState(selected: 'C'), mode),
        ChoiceTileState.correct,
      );
    });

    test('F-4: the first-try choice is incorrect labelled "1st try"', () {
      expectLook(
        choiceLookFor('B', const AnswerState(selected: 'C'), mode),
        ChoiceTileState.incorrect,
        '1st try',
      );
    });

    test('F-4: other choice looks reviewOther', () {
      expectLook(
        choiceLookFor('A', const AnswerState(selected: 'C'), mode),
        ChoiceTileState.reviewOther,
      );
    });

    test('F-4: correct on the first try has no "1st try" tile', () {
      expectLook(
        choiceLookFor(
          'A',
          const AnswerState(selected: 'C'),
          practice(const Correct()),
        ),
        ChoiceTileState.reviewOther,
      );
    });
  });

  group('Revealed', () {
    final mode = practice(
      const Revealed(key: McqAnswerKey('D'), firstTry: 'B'),
    );
    const answer = AnswerState(selected: 'C');

    test('F-4: the key choice looks correctAnswer', () {
      expectLook(
        choiceLookFor('D', answer, mode),
        ChoiceTileState.correctAnswer,
      );
    });

    test('F-4: the first-try choice is incorrect labelled "1st try"', () {
      expectLook(
        choiceLookFor('B', answer, mode),
        ChoiceTileState.incorrect,
        '1st try',
      );
    });

    test('F-4: the selected choice is incorrect labelled "Your answer"', () {
      expectLook(
        choiceLookFor('C', answer, mode),
        ChoiceTileState.incorrect,
        'Your answer',
      );
    });

    test('F-4: other choice looks reviewOther', () {
      expectLook(choiceLookFor('A', answer, mode), ChoiceTileState.reviewOther);
    });
  });
}
