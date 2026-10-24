import 'package:sat_east_client/features/teacher/review/domain/entities/review.dart';

ReviewPage reviewPageFromJson(Object? raw) {
  final json = _object(raw);
  return ReviewPage(
    total: _count(json['total']),
    page: _count(json['page'], min: 1),
    pageSize: _count(json['page_size'], min: 1),
    rows: _array(json['rows']).map((raw) {
      final row = _object(raw);
      return ReviewRow(
        questionId: _text(row['question_id']),
        externalRef: _optional(row['external_ref']),
        stemPreview: _text(row['stem_preview']),
        status: _text(row['status']),
        openCount: _count(row['open_count']),
        reasons: _object(
          row['reasons'],
        ).map((key, value) => MapEntry(key, _count(value))),
        oldestReportAt: row['oldest_report_at'] == null
            ? null
            : _date(row['oldest_report_at']),
        latestNote: _optional(row['latest_note']),
      );
    }).toList(),
  );
}

List<QuestionReport> reportsFromJson(Object? raw) => _array(raw).map((raw) {
  final row = _object(raw);
  return QuestionReport(
    id: _text(row['report_id']),
    reason: _text(row['reason']),
    note: _optional(row['note']),
    createdAt: _date(row['created_at']),
    fullName: _text(row['full_name']),
  );
}).toList();
ReviewCounts countsFromJson(Object? raw) {
  final json = _object(raw);
  return ReviewCounts(
    reported: _count(json['reported']),
    needsReview: _count(json['needs_review']),
  );
}

int closedFromJson(Object? raw) => _count(_object(raw)['closed']);
Map<String, Object?> _object(Object? raw) {
  if (raw is! Map<String, Object?>) throw const FormatException('object');
  return raw;
}

List<Object?> _array(Object? raw) {
  if (raw is! List<Object?>) throw const FormatException('array');
  return raw;
}

String _text(Object? raw) {
  if (raw is! String) throw const FormatException('text');
  return raw;
}

String? _optional(Object? raw) => raw == null ? null : _text(raw);
int _count(Object? raw, {int min = 0}) {
  if (raw is! int || raw < min) throw const FormatException('count');
  return raw;
}

DateTime _date(Object? raw) {
  final date = DateTime.tryParse(_text(raw));
  if (date == null) throw const FormatException('date');
  return date;
}
