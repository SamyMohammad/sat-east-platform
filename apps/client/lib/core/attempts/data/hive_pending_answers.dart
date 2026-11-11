import 'dart:async';
import 'dart:convert';

import 'package:hive_ce/hive.dart';
import 'package:sat_east_client/core/attempts/pending_answers.dart';
import 'package:sat_east_client/core/observability/error_reporter.dart';

/// [PendingAnswers] backed by a Hive box.
///
/// Hive commits a write to its in-memory keystore only after the disk write
/// finishes, so reads would not see a `put` made in the same turn. Entries are
/// therefore mirrored in [_cache] (loaded once at construction); the box is the
/// durable copy and is written without awaiting.
class HivePendingAnswers implements PendingAnswers {
  HivePendingAnswers(
    this._box, {
    required this._reporter,
    this._now = DateTime.now,
  }) {
    _load();
  }

  final Box<String> _box;
  final ErrorReporter _reporter;
  final DateTime Function() _now;
  final _cache = <String, PendingAnswer>{};

  static String _key(String attemptId, String questionId) =>
      '$attemptId:$questionId';

  void _load() {
    final corrupt = <String>[];
    for (final key in _box.keys.whereType<String>()) {
      final raw = _box.get(key);
      try {
        final separator = key.indexOf(':');
        if (raw == null || separator <= 0 || separator == key.length - 1) {
          throw const FormatException('pending answer key');
        }
        final json = jsonDecode(raw);
        if (json is! Map<String, Object?>) {
          throw const FormatException('pending answer');
        }
        _cache[key] = PendingAnswer.fromJson(json);
      } on FormatException catch (error, stack) {
        corrupt.add(key);
        unawaited(
          _reporter.captureError(
            error,
            stack,
            hint: 'Discard corrupt pending answer',
          ),
        );
      }
    }
    if (corrupt.isNotEmpty) {
      _guard(_box.deleteAll(corrupt), 'Delete corrupt pending answers');
    }
  }

  void _guard(Future<void> write, String hint) {
    unawaited(
      write.catchError((Object error, StackTrace stack) {
        unawaited(_reporter.captureError(error, stack, hint: hint));
      }),
    );
  }

  @override
  int put(
    String attemptId,
    String questionId, {
    required bool marked,
    required int timeMs,
    String? answer,
  }) {
    final key = _key(attemptId, questionId);
    final rev = (_cache[key]?.rev ?? 0) + 1;
    final entry = PendingAnswer(
      answer: answer,
      marked: marked,
      timeMs: timeMs,
      rev: rev,
      savedAt: _now(),
    );
    _cache[key] = entry;
    _guard(_box.put(key, jsonEncode(entry.toJson())), 'Save pending answer');
    return rev;
  }

  @override
  int? revOf(String attemptId, String questionId) =>
      _cache[_key(attemptId, questionId)]?.rev;

  @override
  void ack(String attemptId, String questionId, int rev) {
    final key = _key(attemptId, questionId);
    if (_cache[key]?.rev != rev) return;
    _cache.remove(key);
    _guard(_box.delete(key), 'Remove acknowledged answer');
  }

  @override
  Map<String, PendingAnswer> forAttempt(String attemptId) {
    final prefix = '$attemptId:';
    return {
      for (final entry in _cache.entries)
        if (entry.key.startsWith(prefix))
          entry.key.substring(prefix.length): entry.value,
    };
  }

  @override
  void clearAttempt(String attemptId) {
    final prefix = '$attemptId:';
    _remove(_cache.keys.where((key) => key.startsWith(prefix)).toList());
  }

  @override
  void pruneOlderThan(DateTime cutoff) {
    _remove([
      for (final entry in _cache.entries)
        if (entry.value.savedAt.isBefore(cutoff)) entry.key,
    ]);
  }

  void _remove(List<String> keys) {
    if (keys.isEmpty) return;
    keys.forEach(_cache.remove);
    _guard(_box.deleteAll(keys), 'Remove pending answers');
  }
}
