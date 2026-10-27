import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/text/text_direction.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/widgets/bank_table.dart';
import 'package:sat_east_client/features/teacher/review/domain/entities/review.dart';
import 'package:sat_east_client/features/teacher/review/presentation/review_copy.dart';

class ReviewQueueTable extends StatelessWidget {
  const ReviewQueueTable({required this.page, super.key});
  final ReviewPage page;
  @override
  Widget build(BuildContext context) => BankDataTable(
    columns: const [
      DataColumn(label: Text('Ref')),
      DataColumn(label: Text('Stem')),
      DataColumn(label: Text('Reports')),
      DataColumn(label: Text('Reasons')),
      DataColumn(label: Text('Latest note')),
    ],
    rows: [
      for (final row in page.rows)
        DataRow(
          key: ValueKey(row.questionId),
          onSelectChanged: (_) => context.go(
            '/teacher/questions/${Uri.encodeComponent(row.questionId)}',
          ),
          cells: [
            DataCell(
              SizedBox(
                width: 110,
                child: Text(
                  row.externalRef ?? 'No ref',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: detectTextDirection(row.externalRef ?? ''),
                ),
              ),
            ),
            DataCell(BankStemPreview(row.stemPreview)),
            DataCell(Text('${row.openCount}')),
            DataCell(
              SizedBox(
                width: 260,
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: BookletSpace.s1,
                    children: [
                      for (final reason in row.reasons.entries)
                        Chip(
                          label: Text(
                            '${reviewReasonLabel(reason.key)} '
                            '(${reason.value})',
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            DataCell(
              SizedBox(
                width: 240,
                child: Text(
                  row.latestNote ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textDirection: detectTextDirection(row.latestNote ?? ''),
                ),
              ),
            ),
          ],
        ),
    ],
  );
}
