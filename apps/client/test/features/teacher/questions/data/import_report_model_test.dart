import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/features/teacher/questions/data/models/import_report_model.dart';

import '../import_fixtures.dart';

void main() {
  test('QB-05: report model parses counts and errors', () {
    expect(importReportFromJson(reportJson), cleanReport);
    final report = importReportFromJson({
      ...reportJson,
      'ok': false,
      'errors': [
        {
          'row': 0,
          'external_ref': null,
          'field': 'rows',
          'problem': 'too_many_rows',
        },
      ],
      'truncated': true,
    });
    expect(report.errors.single.row, 0);
    expect(report.errors.single.externalRef, isNull);
    expect(report.truncated, isTrue);
  });
  for (final raw in <Object?>[
    null,
    [],
    {},
    {...reportJson, 'rows': '2'},
    {
      ...reportJson,
      'errors': [12],
    },
    {...reportJson, 'new': -1},
  ]) {
    test(
      'QB-05: malformed report is rejected $raw',
      () => expect(() => importReportFromJson(raw), throwsFormatException),
    );
  }
}
