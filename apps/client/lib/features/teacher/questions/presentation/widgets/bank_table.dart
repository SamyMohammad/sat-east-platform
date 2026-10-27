import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/math_render/math_text.dart';
import 'package:sat_east_client/core/text/text_direction.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/bank_page.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/bank_copy.dart';

class BankTable extends StatelessWidget {
  const BankTable({required this.page, super.key});
  final BankPage page;
  @override
  Widget build(BuildContext context) => BankDataTable(
    columns: const [
      DataColumn(label: Text('Ref')),
      DataColumn(label: Text('Stem')),
      DataColumn(label: Text('Type')),
      DataColumn(label: Text('Topic')),
      DataColumn(label: Text('Difficulty')),
      DataColumn(label: Text('Pool')),
      DataColumn(label: Text('Status')),
    ],
    rows: [
      for (final row in page.rows)
        DataRow(
          key: ValueKey(row.id),
          onSelectChanged: (_) =>
              context.go('/teacher/questions/${Uri.encodeComponent(row.id)}'),
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
            DataCell(
              SizedBox(width: 48, child: Text(bankValueLabel(row.type))),
            ),
            DataCell(
              SizedBox(
                width: 120,
                child: Text(
                  row.topicTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: detectTextDirection(row.topicTitle),
                ),
              ),
            ),
            DataCell(SizedBox(width: 64, child: Text(row.difficulty))),
            DataCell(
              SizedBox(
                width: 100,
                child: Text(
                  bankValueLabel(row.pool),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            DataCell(
              SizedBox(
                width: 110,
                child: Chip(
                  label: Text(
                    bankValueLabel(row.status),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ),
    ],
  );
}

class BankStemPreview extends StatelessWidget {
  const BankStemPreview(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 260,
    height: 40,
    child: ClipRect(
      child: OverflowBox(
        alignment: AlignmentDirectional.centerStart,
        minHeight: 0,
        maxHeight: double.infinity,
        child: DefaultTextStyle.merge(
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          child: MathText(text),
        ),
      ),
    ),
  );
}

class BankDataTable extends StatelessWidget {
  const BankDataTable({required this.columns, required this.rows, super.key});
  final List<DataColumn> columns;
  final List<DataRow> rows;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      showCheckboxColumn: false,
      columnSpacing: BookletSpace.s4,
      horizontalMargin: BookletSpace.s3,
      columns: columns,
      rows: rows,
    ),
  );
}
