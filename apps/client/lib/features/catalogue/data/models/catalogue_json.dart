Map<String, Object?> jsonObject(Object? value) {
  if (value is! Map) throw const FormatException('Expected object');
  return value.cast<String, Object?>();
}

String jsonString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) throw FormatException(key);
  return value;
}

String? jsonDescription(Map<String, Object?> json) {
  final value = json['description'];
  if (value != null && value is! String) {
    throw const FormatException('description');
  }
  return value as String?;
}

int jsonCount(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int || value < 0) throw FormatException(key);
  return value;
}

List<T> jsonList<T>(Object? value, T Function(Map<String, Object?>) parse) {
  if (value is! List) throw const FormatException('Expected list');
  return List.unmodifiable(value.map((row) => parse(jsonObject(row))));
}
