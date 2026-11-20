import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/attempts/answer_save_queue.dart';
import 'package:sat_east_client/core/attempts/save_outcome.dart';
import 'package:sat_east_client/core/errors/result.dart';

import '../../support/in_memory_pending_answers.dart';

void main() {
  test('MCK-01: the save callback reads eliminated from the outbox entry, '
      'always the latest snapshot', () async {
    final pending = InMemoryPendingAnswers();
    final sent = <(String, int, Set<String>)>[];
    final queue = AnswerSaveQueue(
      clientSeq: 4,
      now: () => DateTime.utc(2026, 11, 17),
      isActive: () => true,
      save: (id, seq) async {
        sent.add((id, seq, pending.forAttempt('a')[id]!.eliminated));
        return const Success(SaveOutcome.saved);
      },
      onError: (_) {},
      onDeadlinePassed: () {},
    );

    pending.put(
      'a',
      'q',
      answer: 'B',
      marked: false,
      timeMs: 1,
      eliminated: {
        'A',
        'D',
      },
    );
    queue.enqueue('q');
    await queue.flushForSubmit();
    expect(sent, hasLength(1));
    expect(sent.single.$2, 5);
    expect(sent.single.$3, {'A', 'D'});

    pending
      ..put('a', 'q', answer: 'B', marked: false, timeMs: 2, eliminated: {'C'})
      ..put(
        'a',
        'q',
        answer: 'B',
        marked: false,
        timeMs: 3,
        eliminated: {
          'C',
          'D',
        },
      );
    queue
      ..resume()
      ..enqueue('q');
    await queue.flushForSubmit();
    expect(sent, hasLength(2));
    expect(sent.last.$2, 6);
    expect(sent.last.$3, {'C', 'D'});
    queue.dispose();
  });
}
