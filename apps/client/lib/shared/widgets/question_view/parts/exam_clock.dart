/// "MM:SS" for a countdown. Rounds partial seconds up, clamps at zero;
/// minutes are unbounded.
String formatClock(Duration remaining) {
  final ms = remaining.inMilliseconds;
  final total = ms <= 0 ? 0 : (ms / Duration.millisecondsPerSecond).ceil();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(total ~/ 60)}:${two(total % 60)}';
}

/// Elapsed share of [budget] in 0..1. A non-positive budget reads as full.
double budgetFraction(Duration remaining, Duration budget) {
  if (budget <= Duration.zero) return 1;
  return ((budget - remaining).inMilliseconds / budget.inMilliseconds).clamp(
    0.0,
    1.0,
  );
}
