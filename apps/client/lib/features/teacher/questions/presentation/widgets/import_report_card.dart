import 'package:flutter/material.dart';
import 'package:sat_east_client/core/text/text_direction.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/import_report.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/import_copy.dart';

class ImportReportCard extends StatelessWidget {
  const ImportReportCard({required this.report, super.key});
  final ImportReport report;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(BookletSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: BookletSpace.s4,
        children: [
          Text(
            '${report.rows} rows: ${report.newCount} new, '
            '${report.updatedCount} updates',
          ),
          if (report.truncated) const Text('Showing first 200'),
          if (report.errors.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Row')),
                  DataColumn(label: Text('Ref')),
                  DataColumn(label: Text('Field')),
                  DataColumn(label: Text('Problem')),
                ],
                rows: report.errors
                    .map(
                      (e) => DataRow(
                        cells: [
                          DataCell(Text('${e.row}')),
                          DataCell(
                            SizedBox(
                              width: 120,
                              child: Text(
                                e.externalRef ?? '',
                                textDirection: detectTextDirection(
                                  e.externalRef ?? '',
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(Text(e.field)),
                          DataCell(
                            SizedBox(
                              width: 240,
                              child: Text(importProblemCopy(e.problem)),
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    ),
  );
}
