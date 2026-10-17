import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/features/practice/domain/entities/practice.dart';

PracticeQuestion _question({
  String id = 'q1',
  PracticeKind kind = PracticeKind.mcq,
  String difficulty = 'E',
  String stemMd = 'Solve.',
  List<PracticeChoice> choices = const [PracticeChoice('A', '1')],
}) => PracticeQuestion(
  id: id,
  kind: kind,
  difficulty: difficulty,
  stemMd: stemMd,
  choices: choices,
);

void main() {
  test('PRC-01: practice choices compare both values', () {
    expect(const PracticeChoice('A', '1'), const PracticeChoice('A', '1'));
    expect(
      const PracticeChoice('A', '1'),
      isNot(const PracticeChoice('B', '1')),
    );
    expect(
      const PracticeChoice('A', '1'),
      isNot(const PracticeChoice('A', '2')),
    );
  });

  test('PRC-01: question equality includes every field', () {
    expect(_question(), _question());
    for (final other in [
      _question(id: 'q2'),
      _question(kind: PracticeKind.spr),
      _question(difficulty: 'H'),
      _question(stemMd: 'Other.'),
      _question(choices: []),
    ]) {
      expect(_question(), isNot(other));
    }
  });

  test(
    'PRC-01: practice set equality includes attempt, target and questions',
    () {
      final set = PracticeSet(
        attemptId: 'a1',
        repTarget: 1,
        questions: [_question()],
      );

      expect(
        set,
        PracticeSet(attemptId: 'a1', repTarget: 1, questions: [_question()]),
      );
      expect(
        set,
        isNot(
          PracticeSet(attemptId: 'a2', repTarget: 1, questions: [_question()]),
        ),
      );
      expect(
        set,
        isNot(
          PracticeSet(attemptId: 'a1', repTarget: 2, questions: [_question()]),
        ),
      );
      expect(
        set,
        isNot(const PracticeSet(attemptId: 'a1', repTarget: 1, questions: [])),
      );
    },
  );

  test('PRC-01: reveal equality preserves type and value', () {
    expect(const ChoiceReveal('B'), const ChoiceReveal('B'));
    expect(const TextReveal('1/2'), const TextReveal('1/2'));
    expect(const ChoiceReveal('B'), isNot(const ChoiceReveal('C')));
    expect(const TextReveal('1/2'), isNot(const TextReveal('2')));
    expect(const ChoiceReveal('B'), isNot(const TextReveal('B')));
  });

  test(
    'PRC-01: correct feedback equality includes try, key and explanation',
    () {
      const correct = CheckCorrect(
        tryNo: 1,
        key: ChoiceReveal('B'),
        explanationMd: 'Why.',
      );

      expect(
        correct,
        const CheckCorrect(
          tryNo: 1,
          key: ChoiceReveal('B'),
          explanationMd: 'Why.',
        ),
      );
      for (final other in [
        const CheckCorrect(
          tryNo: 2,
          key: ChoiceReveal('B'),
          explanationMd: 'Why.',
        ),
        const CheckCorrect(
          tryNo: 1,
          key: ChoiceReveal('C'),
          explanationMd: 'Why.',
        ),
        const CheckCorrect(
          tryNo: 1,
          key: ChoiceReveal('B'),
          explanationMd: 'Other.',
        ),
      ]) {
        expect(correct, isNot(other));
      }
    },
  );

  test('PRC-01: miss equality includes nullable feedback', () {
    expect(
      const CheckMiss(hintMd: 'Hint.', misconceptionMd: 'Note.'),
      const CheckMiss(hintMd: 'Hint.', misconceptionMd: 'Note.'),
    );
    expect(const CheckMiss(), isNot(const CheckMiss(hintMd: 'Hint.')));
    expect(const CheckMiss(), isNot(const CheckMiss(misconceptionMd: 'Note.')));
  });

  test('PRC-01: revealed feedback equality includes key and explanation', () {
    const revealed = CheckRevealed(
      key: TextReveal('1/2'),
      explanationMd: 'Why.',
    );

    expect(
      revealed,
      const CheckRevealed(key: TextReveal('1/2'), explanationMd: 'Why.'),
    );
    expect(
      revealed,
      isNot(const CheckRevealed(key: TextReveal('2'), explanationMd: 'Why.')),
    );
    expect(
      revealed,
      isNot(
        const CheckRevealed(key: TextReveal('1/2'), explanationMd: 'Other.'),
      ),
    );
  });
}
