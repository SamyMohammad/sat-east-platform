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
