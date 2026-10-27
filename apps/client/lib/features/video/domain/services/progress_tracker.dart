import 'package:sat_east_client/features/video/domain/entities/watched_span.dart';

/// Tracks contiguous media positions. Discontinuities never count as watched.
class ProgressTracker {
  ProgressTracker({required int intervalS}) : _maxSpanS = intervalS * 2 {
    if (intervalS <= 0) throw ArgumentError.value(intervalS, 'intervalS');
  }

  final int _maxSpanS;
  final List<WatchedSpan> _closed = [];
  double? _start;
  double? _last;

  bool get hasPending =>
      _closed.isNotEmpty || (_start != null && _last!.floor() > _start!.ceil());

  void onPosition(double s) {
    if (!s.isFinite || s < 0) throw ArgumentError.value(s, 's');
    final last = _last;
    if (last == null) {
      _start = s;
    } else if (s < last || s - last > 1) {
      // Engines report at roughly 4 Hz, including at 1.5x speed.
      _closeSpan();
      _start = s;
    }
    _last = s;
  }

  List<WatchedSpan> takeSpans() {
    final start = _start;
    final last = _last;
    final emittedOpenSpan =
        start != null && last != null && last.floor() > start.ceil();
    _closeSpan();
    final spans = List<WatchedSpan>.unmodifiable(_closed);
    _closed.clear();
    _start = emittedOpenSpan ? last.floorToDouble() : last;
    return spans;
  }

  void _closeSpan() {
    final start = _start;
    final last = _last;
    if (start == null || last == null) return;
    var from = start.ceil();
    final end = last.floor();
    while (from < end) {
      final to = end - from > _maxSpanS ? from + _maxSpanS : end;
      _closed.add(WatchedSpan(fromS: from, toS: to));
      from = to;
    }
  }
}
