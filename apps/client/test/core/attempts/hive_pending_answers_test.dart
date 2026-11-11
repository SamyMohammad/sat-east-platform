import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:sat_east_client/core/attempts/data/hive_pending_answers.dart';
import 'package:sat_east_client/core/observability/error_reporter.dart';

class _Reporter implements ErrorReporter {
  final hints = <String?>[];

  @override
  Future<void> captureError(
    Object error,
    StackTrace? stackTrace, {
    String? hint,
  }) async => hints.add(hint);

  @override
  Future<void> setUser(String userId) async {}

  @override
  Future<void> clearUser() async {}
}

void main() {
  late Directory dir;
  late Box<String> box;
  late DateTime clock;
  late _Reporter reporter;
  var boxCount = 0;

  HivePendingAnswers open() =>
      HivePendingAnswers(box, now: () => clock, reporter: reporter);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('pending_answers_test');
    Hive.init(dir.path);
    box = await Hive.openBox<String>('pending_${boxCount++}');
    clock = DateTime.utc(2026, 11, 11, 12);
    reporter = _Reporter();
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('PRC-03: put stores a snapshot and increments rev from 1', () {
    final store = open();
    expect(store.revOf('a', 'q'), isNull);
    expect(store.put('a', 'q', answer: 'A', marked: false, timeMs: 10), 1);
    expect(store.put('a', 'q', answer: 'B', marked: true, timeMs: 20), 2);
    final entry = store.forAttempt('a')['q']!;
    expect(entry.answer, 'B');
    expect(entry.marked, isTrue);
    expect(entry.timeMs, 20);
    expect(entry.rev, 2);
    expect(entry.savedAt, clock);
    expect(store.revOf('a', 'q'), 2);
  });

  test('PRC-03: ack with a stale rev keeps the newer entry', () {
    final store = open()
      ..put('a', 'q', answer: 'A', marked: false, timeMs: 0)
      ..put('a', 'q', answer: 'B', marked: false, timeMs: 0)
      ..ack('a', 'q', 1);
    expect(store.forAttempt('a')['q']!.answer, 'B');
  });

  test('PRC-03: ack with the current rev removes the entry', () {
    final store = open()
      ..put('a', 'q', answer: 'A', marked: false, timeMs: 0)
      ..ack('a', 'q', 1);
    expect(store.forAttempt('a'), isEmpty);
    expect(store.revOf('a', 'q'), isNull);
  });

  test('PRC-03: forAttempt isolates attempts', () {
    final store = open()
      ..put('a', 'q1', answer: 'A', marked: false, timeMs: 0)
      ..put('b', 'q1', answer: 'C', marked: false, timeMs: 0)
      ..put('a', 'q2', marked: true, timeMs: 0);
    expect(store.forAttempt('a').keys, unorderedEquals(['q1', 'q2']));
    expect(store.forAttempt('b').keys, ['q1']);
    expect(store.forAttempt('b')['q1']!.answer, 'C');
    expect(store.forAttempt('c'), isEmpty);
  });

  test('PRC-03: clearAttempt removes only that attempt', () {
    final store = open()
      ..put('a', 'q1', answer: 'A', marked: false, timeMs: 0)
      ..put('a', 'q2', answer: 'B', marked: false, timeMs: 0)
      ..put('b', 'q1', answer: 'C', marked: false, timeMs: 0)
      ..clearAttempt('a');
    expect(store.forAttempt('a'), isEmpty);
    expect(store.forAttempt('b'), hasLength(1));
  });

  test('PRC-03: pruneOlderThan drops entries saved before the cutoff', () {
    clock = DateTime.utc(2026, 11);
    final store = open()
      ..put('a', 'old', answer: 'A', marked: false, timeMs: 0);
    clock = DateTime.utc(2026, 11, 10);
    store
      ..put('a', 'new', answer: 'B', marked: false, timeMs: 0)
      ..pruneOlderThan(DateTime.utc(2026, 11, 5));
    expect(store.forAttempt('a').keys, ['new']);
  });

  test('PRC-03: entries survive closing and reopening the box', () async {
    final name = box.name;
    open().put('a', 'q', answer: 'A', marked: true, timeMs: 5);
    await box.close();
    box = await Hive.openBox<String>(name);
    final entry = open().forAttempt('a')['q']!;
    expect(entry.answer, 'A');
    expect(entry.marked, isTrue);
    expect(entry.rev, 1);
  });

  test('PRC-03: corrupt entries are skipped, deleted and reported', () async {
    final name = box.name;
    await box.put('a:bad-json', 'not json');
    await box.put('a:bad-shape', '{"rev":"x"}');
    await box.put('nocolon', '{}');
    await box.put(
      'a:good',
      '{"answer":"A","marked":false,"time_ms":1,"rev":1,'
          '"saved_at":"2026-11-11T12:00:00.000Z"}',
    );
    final store = open();
    expect(store.forAttempt('a').keys, ['good']);
    expect(reporter.hints, hasLength(3));
    await box.close();
    box = await Hive.openBox<String>(name);
    expect(box.keys, ['a:good']);
  });
}
