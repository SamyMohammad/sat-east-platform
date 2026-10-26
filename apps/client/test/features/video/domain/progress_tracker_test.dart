import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/features/video/domain/services/progress_tracker.dart';

void main() {
  test('LRN-02: consecutive positions produce watched span 0 to 14', () {
    final tracker = ProgressTracker(intervalS: 15);
    for (var s = 0; s <= 14; s++) {
      tracker.onPosition(s.toDouble());
    }
    expect(tracker.hasPending, isTrue);
    expect(tracker.takeSpans().map((s) => (s.fromS, s.toS)), [(0, 14)]);
    expect(tracker.hasPending, isFalse);
    expect(tracker.takeSpans(), isEmpty);
  });
  test('LRN-02: continuous playback has no gaps across flushes', () {
    final tracker = ProgressTracker(intervalS: 15);
    for (var s = 0; s <= 14; s++) {
      tracker.onPosition(s.toDouble());
    }
    final spans = tracker.takeSpans().toList();
    for (var tick = 0; tick <= 62; tick++) {
      tracker.onPosition(14.3 + tick * 0.25);
    }
    tracker.onPosition(30);
    spans.addAll(tracker.takeSpans());
    expect(spans.map((s) => (s.fromS, s.toS)), [(0, 14), (14, 30)]);
  });
  test('LRN-02: fractional heartbeat boundaries stay adjacent', () {
    final tracker = ProgressTracker(intervalS: 15);
    for (var tick = 0; tick <= 27; tick++) {
      tracker.onPosition(tick * 0.25);
    }
    expect(tracker.takeSpans().map((s) => (s.fromS, s.toS)), [(0, 6)]);
    for (var tick = 28; tick <= 85; tick++) {
      tracker.onPosition(tick * 0.25);
    }
    expect(tracker.takeSpans().map((s) => (s.fromS, s.toS)), [(6, 21)]);
  });
  test('LRN-02: forward seek closes at old position and skips gap', () {
    final tracker = ProgressTracker(intervalS: 15);
    for (var s = 20; s <= 30; s++) {
      tracker.onPosition(s.toDouble());
    }
    tracker
      ..onPosition(90)
      ..onPosition(91);
    expect(tracker.takeSpans().map((s) => (s.fromS, s.toS)), [
      (20, 30),
      (90, 91),
    ]);
  });
  test('LRN-02: backward seek closes at 50 and restarts at 20', () {
    final tracker = ProgressTracker(intervalS: 15);
    for (var s = 40; s <= 50; s++) {
      tracker.onPosition(s.toDouble());
    }
    tracker
      ..onPosition(20)
      ..onPosition(21);
    expect(tracker.takeSpans().map((s) => (s.fromS, s.toS)), [
      (40, 50),
      (20, 21),
    ]);
  });
  test('LRN-02: half-second ticks split spans at twice interval', () {
    final tracker = ProgressTracker(intervalS: 15);
    for (var tick = 0; tick <= 80; tick++) {
      tracker.onPosition(tick / 2);
    }
    final spans = tracker.takeSpans();
    expect(spans.map((s) => (s.fromS, s.toS)), [(0, 30), (30, 40)]);
    expect(spans.every((s) => s.toS - s.fromS <= 30), isTrue);
  });
  test(
    'LRN-02: drops subsecond spans and does not repeat flushed coverage',
    () {
      final tracker = ProgressTracker(intervalS: 15)
        ..onPosition(0)
        ..onPosition(0.5);
      expect(tracker.takeSpans(), isEmpty);
      expect(tracker.hasPending, isFalse);
      tracker
        ..onPosition(1)
        ..onPosition(2);
      expect(tracker.takeSpans().map((s) => (s.fromS, s.toS)), [(1, 2)]);
      expect(tracker.hasPending, isFalse);
    },
  );
  test('LRN-02: rejects invalid interval and nonfinite positions', () {
    expect(() => ProgressTracker(intervalS: 0), throwsArgumentError);
    final tracker = ProgressTracker(intervalS: 15);
    for (final position in [-1.0, double.nan, double.infinity]) {
      expect(() => tracker.onPosition(position), throwsArgumentError);
    }
  });
}
