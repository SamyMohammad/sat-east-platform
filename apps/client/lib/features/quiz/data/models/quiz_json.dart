Map<String, Object?> quizJsonMap(Object? value, String field) =>
    value is Map<String, Object?> ? value : throw FormatException(field);

List<Object?> quizJsonList(Map<String, Object?> json, String field) {
  final value = json[field];
  return value is List ? value.cast<Object?>() : throw FormatException(field);
}

String quizJsonString(Map<String, Object?> json, String field) {
  final value = json[field];
  return value is String ? value : throw FormatException(field);
}

String quizJsonId(Map<String, Object?> json, String field) {
  final value = quizJsonString(json, field);
  if (value.trim().isEmpty) throw FormatException(field);
  return value;
}

int quizJsonInt(Map<String, Object?> json, String field, {int min = 0}) {
  final value = json[field];
  return value is int && value >= min ? value : throw FormatException(field);
}

double quizJsonPercentage(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is! num || !value.isFinite || value < 0 || value > 100) {
    throw FormatException(field);
  }
  return value.toDouble();
}

bool quizJsonBool(Map<String, Object?> json, String field) {
  final value = json[field];
  return value is bool ? value : throw FormatException(field);
}

Object? quizJsonRequired(Map<String, Object?> json, String field) {
  if (!json.containsKey(field)) throw FormatException(field);
  return json[field];
}

DateTime quizJsonInstant(Map<String, Object?> json, String field) {
  final value = DateTime.tryParse(quizJsonString(json, field));
  if (value == null || !value.isUtc) throw FormatException(field);
  return value;
}
