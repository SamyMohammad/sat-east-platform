import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/shared/widgets/question_view/answer_state.dart';
import 'package:sat_east_client/shared/widgets/question_view/practice_feedback.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view_mode.dart';

QuizMode _quiz({
  int index = 3,
  int total = 12,
  Duration remaining = const Duration(minutes: 14),
  Duration warnAt = const Duration(minutes: 5),
}) => QuizMode(
  title: 'Quiz 4.2',
  index: index,
  total: total,
  remaining: remaining,
  timeBudget: const Duration(minutes: 18),
  warnAt: warnAt,
);

HomeworkMode _homework({int index = 3, int total = 12}) => HomeworkMode(
  title: 'Homework 4.2',
  index: index,
  total: total,
  saveStatus: SaveStatus.saved,
);

PracticeMode _practice([PracticeFeedback feedback = const Idle()]) =>
    PracticeMode(feedback: feedback, rep: 1, repTarget: 3);

void _noop() {}

void main() {
  test(
    'F-4: QuestionData exposes no answer key, explanation or misconception',
    () {
      final src = File(
        'lib/shared/widgets/question_view/question_data.dart',
      ).readAsStringSync().replaceAll(RegExp('//.*'), ''); // ignore comments
      for (final banned in [
        'key',
        'answer',
        'explanation',
        'misconception',
        'hint',
        'correct',
      ]) {
        expect(
          RegExp(
            '\\bfinal\\s+\\S+\\s+\\w*$banned\\w*\\s*;',
            caseSensitive: false,
          ).hasMatch(src),
          isFalse,
          reason: 'field containing "$banned" in QuestionData',
        );
      }
    },
  );

  group('AnswerState.hasAnswer', () {
    test('F-4: is false for the default state', () {
      expect(const AnswerState().hasAnswer, isFalse);
    });

    test('F-4: is true when a choice is selected', () {
      expect(const AnswerState(selected: 'B').hasAnswer, isTrue);
    });

    test('F-4: is true when SPR text is entered', () {
      expect(const AnswerState(sprText: '3/4').hasAnswer, isTrue);
    });

    test('F-4: is false for whitespace-only SPR text', () {
      expect(const AnswerState(sprText: '   ').hasAnswer, isFalse);
    });

    test('F-4: eliminated choices and mark alone are not an answer', () {
      expect(
        const AnswerState(eliminated: {'A'}, marked: true).hasAnswer,
        isFalse,
      );
    });
  });

  group('QuizMode time gating', () {
    test('F-4: isTimeUp is false while time remains', () {
      expect(_quiz(remaining: const Duration(seconds: 1)).isTimeUp, isFalse);
    });

    test('F-4: isTimeUp is true at exactly zero', () {
      expect(_quiz(remaining: Duration.zero).isTimeUp, isTrue);
    });

    test('F-4: isTimeUp is true below zero', () {
      expect(
        _quiz(remaining: const Duration(seconds: -3)).isTimeUp,
        isTrue,
      );
    });

    test('F-4: isTimeUp is false for practice and homework', () {
      expect(_practice().isTimeUp, isFalse);
      expect(_homework().isTimeUp, isFalse);
    });

    test('F-4: isWarning is false just above warnAt', () {
      final mode = _quiz(remaining: const Duration(minutes: 5, seconds: 1));
      expect(mode.isWarning, isFalse);
    });

    test('F-4: isWarning is true exactly at warnAt', () {
      final mode = _quiz(remaining: const Duration(minutes: 5));
      expect(mode.isWarning, isTrue);
    });

    test('F-4: isWarning is true below warnAt and at time-up', () {
      expect(
        _quiz(remaining: const Duration(minutes: 4, seconds: 41)).isWarning,
        isTrue,
      );
      expect(_quiz(remaining: Duration.zero).isWarning, isTrue);
    });

    test('F-4: isWarning is false for practice and homework', () {
      expect(_practice().isWarning, isFalse);
      expect(_homework().isWarning, isFalse);
    });
  });

  group('choicesInteractive for QuizMode', () {
    test('F-4: is true while time remains', () {
      expect(_quiz().choicesInteractive, isTrue);
    });

    test('F-4: is false at time-up', () {
      expect(_quiz(remaining: Duration.zero).choicesInteractive, isFalse);
    });
  });

  group('forwardAction', () {
    test('F-4: quiz returns onNext mid-way', () {
      expect(_quiz().forwardAction(_noop), same(_noop));
    });

    test('F-4: quiz returns null on the last question', () {
      expect(_quiz(index: 11).forwardAction(_noop), isNull);
    });

    test('F-4: quiz returns null at time-up', () {
      expect(_quiz(remaining: Duration.zero).forwardAction(_noop), isNull);
    });

    test('F-4: homework returns onNext until the last question', () {
      expect(_homework().forwardAction(_noop), same(_noop));
      expect(_homework(index: 11).forwardAction(_noop), isNull);
    });

    test('F-4: practice returns onNext only when Correct or Revealed', () {
      expect(_practice().forwardAction(_noop), isNull);
      expect(_practice(const Correct()).forwardAction(_noop), same(_noop));
    });
  });

  group('backAction', () {
    test('F-4: quiz returns onPrev after the first question', () {
      expect(_quiz().backAction(_noop), same(_noop));
    });

    test('F-4: quiz returns null on the first question', () {
      expect(_quiz(index: 0).backAction(_noop), isNull);
    });

    test('F-4: quiz returns null at time-up', () {
      expect(_quiz(remaining: Duration.zero).backAction(_noop), isNull);
    });

    test('F-4: homework returns null only on the first question', () {
      expect(_homework().backAction(_noop), same(_noop));
      expect(_homework(index: 0).backAction(_noop), isNull);
    });

    test('F-4: practice always returns onPrev', () {
      expect(_practice().backAction(_noop), same(_noop));
    });
  });

  group('markAction', () {
    test('F-4: quiz returns onMark while time remains', () {
      expect(_quiz().markAction(_noop), same(_noop));
    });

    test('F-4: quiz returns null at time-up', () {
      expect(_quiz(remaining: Duration.zero).markAction(_noop), isNull);
    });

    test('F-4: practice and homework return onMark', () {
      expect(_practice().markAction(_noop), same(_noop));
      expect(_homework().markAction(_noop), same(_noop));
    });

    test('F-4: a null onMark stays null', () {
      expect(_quiz().markAction(null), isNull);
      expect(_homework().markAction(null), isNull);
    });
  });

  group('submitAction', () {
    test('F-4: quiz returns onSubmit while time remains', () {
      expect(_quiz().submitAction(_noop), same(_noop));
    });

    test('F-4: quiz returns null at time-up', () {
      expect(_quiz(remaining: Duration.zero).submitAction(_noop), isNull);
    });

    test('F-4: homework returns onSubmit', () {
      expect(_homework().submitAction(_noop), same(_noop));
    });

    test('F-4: practice returns null', () {
      expect(_practice().submitAction(_noop), isNull);
    });
  });
}
