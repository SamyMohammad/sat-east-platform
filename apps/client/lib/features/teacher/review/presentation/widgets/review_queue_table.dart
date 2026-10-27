import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/core/theme/app_type.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/widgets/bank_table.dart';
import 'package:sat_east_client/features/teacher/review/domain/entities/review.dart';
import 'package:sat_east_client/features/teacher/review/presentation/review_copy.dart';
import 'package:sat_east_client/shared/widgets/app_chip.dart';

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
                  textDirection: TextDirection.ltr,
                ),
              ),
            ),
            DataCell(BankStemPreview(row.stemPreview)),
            DataCell(Text('${row.openCount}', style: AppType.count)),
            DataCell(
              SizedBox(
                width: 260,
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: AppSpace.s1,
                    children: [
                      for (final reason in row.reasons.entries)
                        AppChip(
                          icon: AppIcons.reviewQueue,
                          label:
                              '${reviewReasonLabel(reason.key)} '
                              '(${reason.value})',
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
                  textDirection: TextDirection.ltr,
                ),
              ),
            ),
          ],
        ),
    ],
  );
}
