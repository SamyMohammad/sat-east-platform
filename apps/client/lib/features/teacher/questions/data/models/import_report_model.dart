import 'package:sat_east_client/features/teacher/questions/domain/entities/import_report.dart';

ImportReport importReportFromJson(Object? raw) {
  if (raw is! Map<String, Object?>) throw const FormatException('report');
  final errors = raw['errors'];
  if (raw['ok'] is! bool ||
      raw['truncated'] is! bool ||
      errors is! List<Object?>) {
    throw const FormatException('report');
  }
  return ImportReport(
    ok: raw['ok']! as bool,
    rows: _count(raw['rows']),
    newCount: _count(raw['new']),
    updatedCount: _count(raw['updated']),
    truncated: raw['truncated']! as bool,
    errors: errors.map((e) {
      if (e is! Map<String, Object?> ||
          e['field'] is! String ||
          e['problem'] is! String ||
          (e['external_ref'] != null && e['external_ref'] is! String)) {
        throw const FormatException('problem');
      }
      return ImportProblem(
        row: _count(e['row']),
        externalRef: e['external_ref'] as String?,
        field: e['field']! as String,
        problem: e['problem']! as String,
      );
    }).toList(),
  );
}

int _count(Object? raw) {
  if (raw is! int || raw < 0) throw const FormatException('count');
  return raw;
}
