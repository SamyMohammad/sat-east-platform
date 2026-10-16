const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "Last used today 09:05" / "yesterday 21:30" / "3 Oct", relative to [now]
/// (injected so tests need no real clock).
String lastUsedText(DateTime seen, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(seen.year, seen.month, seen.day);
  final days = today.difference(day).inDays;
  final time =
      '${seen.hour.toString().padLeft(2, '0')}:'
      '${seen.minute.toString().padLeft(2, '0')}';
  return switch (days) {
    0 => 'Last used today $time',
    1 => 'Last used yesterday $time',
    _ => 'Last used ${seen.day} ${_months[seen.month - 1]}',
  };
}
