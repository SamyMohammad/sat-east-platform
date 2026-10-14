import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/shared/widgets/question_view/answer_state.dart';

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
}
