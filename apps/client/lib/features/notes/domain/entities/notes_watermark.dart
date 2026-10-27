class NotesWatermark {
  const NotesWatermark({
    required this.fullName,
    required this.email,
    required this.date,
  });
  final String fullName;
  final String email;
  final DateTime date;
  String get text {
    final day = [
      date.year.toString().padLeft(4, '0'),
      date.month.toString().padLeft(2, '0'),
      date.day.toString().padLeft(2, '0'),
    ].join('-');
    return '$fullName \u00b7 ${email.split('@').first} \u00b7 $day';
  }
}
