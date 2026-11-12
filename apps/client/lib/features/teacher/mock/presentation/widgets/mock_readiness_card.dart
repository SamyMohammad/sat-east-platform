import 'package:flutter/material.dart';
import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/teacher/mock/domain/entities/mock_entities.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/mock_copy.dart';

/// Whether the reserve bank can fill another form, with the shortage list
/// and the collapsed per-form blueprint.
class MockReadinessCard extends StatelessWidget {
  const MockReadinessCard({
    required this.missing,
    required this.noDomain,
    required this.needPerForm,
    super.key,
  });
  final List<MockShortageCell> missing;
  final int noDomain;
  final List<MockCell> needPerForm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final ready = missing.isEmpty;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpace.s3,
          children: [
            Row(
              spacing: AppSpace.s2,
              children: [
                Icon(
                  ready ? AppIcons.correct : AppIcons.masteryWeak,
                  color: ready ? colors.correct : colors.warning,
                ),
                Expanded(
                  child: Text(
                    ready ? mockReadyLine : mockShortLine,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            for (final cell in missing)
              Text(mockShortageLine(cell), style: theme.textTheme.bodyMedium),
            if (noDomain > 0)
              Text(
                mockNoDomainLine(noDomain),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.inkSecondary,
                ),
              ),
            _NeedPerForm(cells: needPerForm),
          ],
        ),
      ),
    );
  }
}

class _NeedPerForm extends StatelessWidget {
  const _NeedPerForm({required this.cells});
  final List<MockCell> cells;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = cells.fold<int>(0, (sum, c) => sum + c.count);
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        expandedAlignment: Alignment.centerLeft,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(mockNeedTitle, style: theme.textTheme.titleSmall),
        children: [
          Text(
            mockPerFormTotal(total),
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: AppSpace.s2),
          for (final cell in cells)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s1),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      mockCellLabel(cell.domain, cell.difficulty, cell.type),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Text('${cell.count}', style: theme.textTheme.labelLarge),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
