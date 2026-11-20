/// Server-relative countdown for one mock module, kept apart from the time
/// spent viewing each question. The offset between the server clock and the
/// device clock is fixed when the module opens.
class MockAttemptClock {
  MockAttemptClock({
    required this._deadline,
    required DateTime serverNow,
    required this._now,
  }) : _offset = serverNow.difference(_now());

  final DateTime Function() _now;
  final DateTime _deadline;
  final Duration _offset;
  final _elapsed = <String, int>{};
  String? _shownId;
  DateTime? _shownAt;

  Duration get remaining {
    final value = _deadline.difference(_now().add(_offset));
    return value.isNegative ? Duration.zero : value;
  }

  int timeMs(String questionId) {
    final shownAt = _shownAt;
    final elapsed = _elapsed[questionId] ?? 0;
    if (_shownId != questionId || shownAt == null) return elapsed;
    final visible = _now().difference(shownAt).inMilliseconds;
    return elapsed + (visible < 0 ? 0 : visible);
  }

  void show(String questionId) {
    pause();
    _shownId = questionId;
    _shownAt = _now();
  }

  void pause() {
    final id = _shownId;
    if (id != null) _elapsed[id] = timeMs(id);
    _shownId = null;
    _shownAt = null;
  }
}

/// Countdown to a server instant (the break between modules).
class MockCountdown {
  MockCountdown({
    required this._until,
    required DateTime serverNow,
    required this._now,
  }) : _offset = serverNow.difference(_now());

  final DateTime Function() _now;
  final DateTime _until;
  final Duration _offset;

  Duration get remaining {
    final value = _until.difference(_now().add(_offset));
    return value.isNegative ? Duration.zero : value;
  }
}
