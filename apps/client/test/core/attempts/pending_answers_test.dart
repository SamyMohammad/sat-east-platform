import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/attempts/pending_answers.dart';

void main() {
  test('PRC-03: PendingAnswer JSON round-trips', () {
    final value = PendingAnswer(
      answer: 'B',
      marked: true,
      timeMs: 4200,
      rev: 3,
      savedAt: DateTime.utc(2026, 11, 11, 9, 30),
    );
    expect(PendingAnswer.fromJson(value.toJson()), value);
  });

  test('PRC-03: PendingAnswer JSON round-trips a cleared answer', () {
    final value = PendingAnswer(
      answer: null,
      marked: false,
      timeMs: 0,
      rev: 1,
      savedAt: DateTime.utc(2026),
    );
    expect(PendingAnswer.fromJson(value.toJson()), value);
  });

  test('MCK-01: PendingAnswer JSON round-trips eliminated choices', () {
    final value = PendingAnswer(
      answer: 'B',
      marked: false,
      timeMs: 10,
      rev: 2,
      savedAt: DateTime.utc(2026, 11, 17),
      eliminated: const {'C', 'A'},
    );
    final json = value.toJson();
    expect(json['eliminated'], ['A', 'C']);
    expect(PendingAnswer.fromJson(json), value);
  });

  test('MCK-01: PendingAnswer without eliminated defaults to empty', () {
    final value = PendingAnswer(
      answer: 'B',
      marked: false,
      timeMs: 10,
      rev: 2,
      savedAt: DateTime.utc(2026, 11, 17),
    );
    expect(value.eliminated, isEmpty);
    expect(PendingAnswer.fromJson(value.toJson()).eliminated, isEmpty);
  });

  test('MCK-01: PendingAnswer.fromJson reads the old shape as empty', () {
    final old = PendingAnswer.fromJson(const {
      'answer': 'A',
      'marked': true,
      'time_ms': 5,
      'rev': 1,
      'saved_at': '2026-11-11T00:00:00.000Z',
    });
    expect(old.eliminated, isEmpty);
    expect(old.answer, 'A');
  });

  test('MCK-01: PendingAnswer.fromJson rejects a malformed eliminated', () {
    for (final bad in <Object?>[
      'A',
      1,
      <Object?>[1],
      <Object?>['A', 'A'],
    ]) {
      expect(
        () => PendingAnswer.fromJson({
          'answer': 'A',
          'marked': true,
          'time_ms': 5,
          'rev': 1,
          'saved_at': '2026-11-11T00:00:00.000Z',
          'eliminated': bad,
        }),
        throwsFormatException,
        reason: '$bad',
      );
    }
  });

  test('PRC-03: PendingAnswer.fromJson rejects malformed data', () {
    expect(
      () => PendingAnswer.fromJson(const {'rev': 'x'}),
      throwsFormatException,
    );
    expect(
      () => PendingAnswer.fromJson(const {
        'answer': 1,
        'marked': true,
        'time_ms': 1,
        'rev': 1,
        'saved_at': '2026-01-01T00:00:00.000Z',
      }),
      throwsFormatException,
    );
  });
}
