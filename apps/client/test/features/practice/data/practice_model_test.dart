import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/features/practice/data/models/practice_model.dart';
import 'package:sat_east_client/features/practice/domain/entities/practice.dart';

Map<String, Object?> _question() => {
  'id': 'q1',
  'type': 'mcq',
  'difficulty': 'M',
  'stem_md': 'Solve **x**.',
  'choices': [
    {'label': 'B', 'body_md': '2'},
  ],
};

Map<String, Object?> _set({Object? question}) => {
  'attempt_id': 'a1',
  'rep_target': 1,
  'questions': [question ?? _question()],
};

Map<String, Object?> _correct() => {
  'is_correct': true,
  'try': 1,
  'key': {'choice': 'B'},
  'explanation_md': 'Because.',
};

void main() {
  group('PRC-01: practiceSetFromJson', () {
    test('PRC-01: parses all question fields', () {
      expect(
        practiceSetFromJson(_set()),
        const PracticeSet(
          attemptId: 'a1',
          repTarget: 1,
          questions: [
            PracticeQuestion(
              id: 'q1',
              kind: PracticeKind.mcq,
              difficulty: 'M',
              stemMd: 'Solve **x**.',
              choices: [PracticeChoice('B', '2')],
            ),
          ],
        ),
      );
    });

    test('PRC-01: parses SPR with empty choices', () {
      final question = _question()
        ..['type'] = 'spr'
        ..['choices'] = <Object?>[];

      final result = practiceSetFromJson(_set(question: question));

      expect(result.questions.single.kind, PracticeKind.spr);
      expect(result.questions.single.choices, isEmpty);
    });

    for (final field in ['attempt_id', 'rep_target', 'questions']) {
      test('PRC-01: missing $field throws FormatException', () {
        final json = _set()..remove(field);

        expect(() => practiceSetFromJson(json), throwsFormatException);
      });
    }

    for (final (field, value) in <(String, Object?)>[
      ('attempt_id', 1),
      ('rep_target', '1'),
      ('rep_target', 1.0),
      ('questions', {}),
      ('questions', [null]),
      ('questions', ['question']),
    ]) {
      test('PRC-01: invalid $field=$value throws FormatException', () {
        final json = _set()..[field] = value;

        expect(() => practiceSetFromJson(json), throwsFormatException);
      });
    }

    for (final field in ['id', 'type', 'difficulty', 'stem_md', 'choices']) {
      test('PRC-01: missing question $field throws FormatException', () {
        final question = _question()..remove(field);

        expect(
          () => practiceSetFromJson(_set(question: question)),
          throwsFormatException,
        );
      });
    }

    for (final (field, value) in <(String, Object?)>[
      ('id', 1),
      ('type', 'essay'),
      ('type', null),
      ('difficulty', 'easy'),
      ('difficulty', 1),
      ('stem_md', false),
      ('choices', null),
      ('choices', [false]),
      (
        'choices',
        [
          {'label': 'A'},
        ],
      ),
      (
        'choices',
        [
          {'body_md': '1'},
        ],
      ),
      (
        'choices',
        [
          {'label': 1, 'body_md': '1'},
        ],
      ),
      (
        'choices',
        [
          {'label': 'A', 'body_md': false},
        ],
      ),
    ]) {
      test('PRC-01: invalid question $field=$value throws FormatException', () {
        final question = _question()..[field] = value;

        expect(
          () => practiceSetFromJson(_set(question: question)),
          throwsFormatException,
        );
      });
    }
  });

  group('PRC-01: checkResultFromJson', () {
    for (final tryNo in [1, 2]) {
      test('PRC-01: parses correct try $tryNo with choice key', () {
        final json = _correct()..['try'] = tryNo;

        expect(
          checkResultFromJson(json),
          CheckCorrect(
            tryNo: tryNo,
            key: const ChoiceReveal('B'),
            explanationMd: 'Because.',
          ),
        );
      });
    }

    test('PRC-01: parses wrong try one with feedback', () {
      expect(
        checkResultFromJson({
          'is_correct': false,
          'try': 1,
          'hint_md': 'Hint.',
          'misconception_md': 'Note.',
        }),
        const CheckMiss(hintMd: 'Hint.', misconceptionMd: 'Note.'),
      );
    });

    test('PRC-01: parses nullable first-miss feedback', () {
      expect(
        checkResultFromJson({
          'is_correct': false,
          'try': 1,
          'hint_md': null,
          'misconception_md': null,
        }),
        const CheckMiss(),
      );
    });

    for (final correct in [true, false]) {
      test('PRC-01: parses nullable explanation for is_correct=$correct', () {
        final json = _correct()
          ..['is_correct'] = correct
          ..['try'] = 2
          ..['explanation_md'] = null;

        expect(
          checkResultFromJson(json),
          correct
              ? const CheckCorrect(
                  tryNo: 2,
                  key: ChoiceReveal('B'),
                  explanationMd: null,
                )
              : const CheckRevealed(
                  key: ChoiceReveal('B'),
                  explanationMd: null,
                ),
        );
      });

      test('PRC-01: parses text reveal for is_correct=$correct', () {
        final json = _correct()
          ..['is_correct'] = correct
          ..['try'] = 2
          ..['key'] = {'text': '1/2'};

        final result = checkResultFromJson(json);

        expect(
          result,
          correct
              ? const CheckCorrect(
                  tryNo: 2,
                  key: TextReveal('1/2'),
                  explanationMd: 'Because.',
                )
              : const CheckRevealed(
                  key: TextReveal('1/2'),
                  explanationMd: 'Because.',
                ),
        );
      });
    }

    for (final field in ['is_correct', 'try', 'key']) {
      test('PRC-01: correct missing $field throws FormatException', () {
        final json = _correct()..remove(field);

        expect(() => checkResultFromJson(json), throwsFormatException);
      });
    }

    for (final (field, value) in <(String, Object?)>[
      ('is_correct', 'true'),
      ('try', '1'),
      ('try', 1.0),
      ('try', 0),
      ('try', 3),
      ('key', null),
      ('key', 'B'),
      ('key', <String, Object?>{}),
      ('key', {'choice': 1}),
      ('key', {'text': false}),
      ('key', {'choice': 'B', 'text': '2'}),
      ('explanation_md', 2),
    ]) {
      test('PRC-01: invalid correct $field=$value throws FormatException', () {
        final json = _correct()..[field] = value;

        expect(() => checkResultFromJson(json), throwsFormatException);
      });
    }

    for (final field in ['hint_md', 'misconception_md']) {
      test('PRC-01: mistyped $field throws FormatException', () {
        final json = <String, Object?>{
          'is_correct': false,
          'try': 1,
          'hint_md': null,
          'misconception_md': null,
          field: 1,
        };

        expect(() => checkResultFromJson(json), throwsFormatException);
      });
    }

    test('PRC-01: wrong try two without key throws FormatException', () {
      expect(
        () => checkResultFromJson({
          'is_correct': false,
          'try': 2,
          'explanation_md': 'Because.',
        }),
        throwsFormatException,
      );
    });
  });
}
