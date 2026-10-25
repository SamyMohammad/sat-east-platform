Map<String, Object?> attemptJsonMap(Object? value, String field) =>
    value is Map<String, Object?> ? value : throw FormatException(field);

List<Object?> attemptJsonList(Map<String, Object?> json, String field) {
  final value = json[field];
  return value is List ? value.cast<Object?>() : throw FormatException(field);
}

String attemptJsonString(Map<String, Object?> json, String field) {
  final value = json[field];
  return value is String ? value : throw FormatException(field);
}

String attemptJsonId(Map<String, Object?> json, String field) {
  final value = attemptJsonString(json, field);
  if (value.trim().isEmpty) throw FormatException(field);
  return value;
}

int attemptJsonInt(Map<String, Object?> json, String field, {int min = 0}) {
  final value = json[field];
  return value is int && value >= min ? value : throw FormatException(field);
}

double attemptJsonPercentage(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is! num || !value.isFinite || value < 0 || value > 100) {
    throw FormatException(field);
  }
  return value.toDouble();
}

bool attemptJsonBool(Map<String, Object?> json, String field) {
  final value = json[field];
  return value is bool ? value : throw FormatException(field);
}

Object? attemptJsonRequired(Map<String, Object?> json, String field) {
  if (!json.containsKey(field)) throw FormatException(field);
  return json[field];
}

DateTime attemptJsonInstant(Map<String, Object?> json, String field) {
  final value = DateTime.tryParse(attemptJsonString(json, field));
  if (value == null || !value.isUtc) throw FormatException(field);
  return value;
}
