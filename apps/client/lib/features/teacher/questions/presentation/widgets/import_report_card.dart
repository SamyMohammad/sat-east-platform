import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/core/theme/app_type.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/import_report.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/import_copy.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/widgets/bank_table.dart';

class ImportReportCard extends StatelessWidget {
  const ImportReportCard({required this.report, super.key});
  final ImportReport report;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    color: context.appColors.background,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
      side: BorderSide(color: context.appColors.line),
    ),
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpace.s4,
        children: [
          Text(
            '${report.rows} rows: ${report.newCount} new, '
            '${report.updatedCount} updates',
          ),
          if (report.truncated) const Text('Showing first 200'),
          if (report.errors.isNotEmpty)
            BankDataTable(
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
                        DataCell(Text('${e.row}', style: AppType.count)),
                        DataCell(
                          SizedBox(
                            width: 120,
                            child: Text(
                              e.externalRef ?? '',
                              textDirection: TextDirection.ltr,
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
        ],
      ),
    ),
  );
}
