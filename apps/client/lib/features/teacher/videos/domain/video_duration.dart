// PostgreSQL int4 upper bound for duration_s.
const _maxDurationS = 0x7fffffff;

bool validVideoDuration(int seconds) => seconds > 0 && seconds <= _maxDurationS;

/// Converts the dialog's mm:ss input to the RPC's positive int4 seconds.
int? parseVideoDuration(String input) {
  final match = RegExp(r'^(\d+):([0-5]\d)$').firstMatch(input.trim());
  if (match == null) {
    return null;
  }
  final minutes = int.tryParse(match[1]!);
  final seconds = int.tryParse(match[2]!);
  if (minutes == null ||
      seconds == null ||
      minutes > _maxDurationS ~/ Duration.secondsPerMinute) {
    return null;
  }
  final duration = minutes * Duration.secondsPerMinute + seconds;
  return validVideoDuration(duration) ? duration : null;
}
