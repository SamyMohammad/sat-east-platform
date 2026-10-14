import 'dart:async';

import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/shared/widgets/booklet_overlays.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';
import 'package:sat_east_client/shared/widgets/painters/dashed_border.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/homework_submit_dialog.dart';

/// Grid of numbered question cells: current, answered, unanswered, marked.
/// Built eagerly (a homework has tens of questions, not thousands).
class HomeworkNavigatorGrid extends StatelessWidget {
  const HomeworkNavigatorGrid({
    required this.total,
    required this.index,
    required this.answered,
    required this.marked,
    required this.columns,
    super.key,
    this.onJumpTo,
  });

  final int total;
  final int index;
  final Set<int> answered;
  final Set<int> marked;
  final int columns;
  final ValueChanged<int>? onJumpTo;

  @override
  Widget build(BuildContext context) {
    const cell = BookletSize.navigatorCell;
    const gap = BookletSpace.s2;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: columns * cell + (columns - 1) * gap,
      ),
      child: Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (var i = 0; i < total; i++)
            _NavigatorCell(
              key: ValueKey('nav-cell-$i'),
              number: i + 1,
              isCurrent: i == index,
              isAnswered: answered.contains(i),
              isMarked: marked.contains(i),
              onTap: onJumpTo == null ? null : () => onJumpTo!(i),
            ),
        ],
      ),
    );
  }
}

class _NavigatorCell extends StatelessWidget {
  const _NavigatorCell({
    required this.number,
    required this.isCurrent,
    required this.isAnswered,
    required this.isMarked,
    required this.onTap,
    super.key,
  });

  final int number;
  final bool isCurrent;
  final bool isAnswered;
  final bool isMarked;
  final VoidCallback? onTap;

  String get _label =>
      'Question $number, ${isAnswered ? 'answered' : 'unanswered'}'
      '${isMarked ? ', marked' : ''}${isCurrent ? ', current' : ''}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = BorderRadius.circular(BookletRadius.sm);
    final textColor = isAnswered ? scheme.onPrimary : scheme.onSurfaceVariant;
    final dashed = !isCurrent && !isAnswered;
    return Semantics(
      container: true,
      button: true,
      label: _label,
      child: SizedBox.square(
        dimension: BookletSize.navigatorCell,
        child: Material(
          color: isAnswered ? scheme.primary : Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: ExcludeSemantics(
              child: CustomPaint(
                foregroundPainter: dashed
                    ? DashedBorderPainter(
                        color: scheme.onSurfaceVariant,
                        radius: BookletRadius.sm,
                        strokeWidth: BookletStroke.badge,
                      )
                    : null,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: isCurrent
                        ? Border.all(
                            color: scheme.onSurface,
                            width: BookletStroke.current,
                          )
                        : null,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '$number',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: textColor,
                          fontWeight: isAnswered ? FontWeight.w700 : null,
                        ),
                      ),
                      if (isCurrent)
                        Positioned(
                          bottom: BookletSpace.s1,
                          child: Container(
                            width: BookletSize.navigatorUnderlineWidth,
                            height: BookletSize.navigatorUnderlineHeight,
                            color: textColor,
                          ),
                        ),
                      if (isMarked)
                        Positioned(
                          top: 0,
                          right: BookletSpace.s1,
                          child: Icon(
                            Icons.bookmark_rounded,
                            size: BookletSize.iconStatus,
                            color: textColor,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _Swatch { current, answered, unanswered, marked }

class _LegendItem extends StatelessWidget {
  const _LegendItem(this.swatch, this.label);

  final _Swatch swatch;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = BorderRadius.circular(BookletRadius.xs);
    const size = BookletSize.legendSwatch;
    final mark = switch (swatch) {
      _Swatch.current => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: scheme.onSurface,
            width: BookletStroke.current,
          ),
        ),
      ),
      _Swatch.answered => DecoratedBox(
        decoration: BoxDecoration(color: scheme.primary, borderRadius: radius),
      ),
      _Swatch.unanswered => CustomPaint(
        painter: DashedBorderPainter(
          color: scheme.onSurfaceVariant,
          radius: BookletRadius.xs,
          strokeWidth: BookletStroke.badge,
        ),
      ),
      _Swatch.marked => Icon(
        Icons.bookmark,
        size: size,
        color: scheme.onSurfaceVariant,
      ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: BookletSpace.s2,
      children: [
        ExcludeSemantics(
          child: SizedBox.square(dimension: size, child: mark),
        ),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.showMarked});

  final bool showMarked;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: BookletSpace.s4,
    runSpacing: BookletSpace.s2,
    children: [
      const _LegendItem(_Swatch.current, 'Current'),
      const _LegendItem(_Swatch.answered, 'Answered'),
      const _LegendItem(_Swatch.unanswered, 'Unanswered'),
      if (showMarked) const _LegendItem(_Swatch.marked, 'Marked for review'),
    ],
  );
}

/// Right-hand navigator at `medium` and `expanded` widths.
class HomeworkNavigatorPanel extends StatelessWidget {
  const HomeworkNavigatorPanel({
    required this.title,
    required this.total,
    required this.index,
    required this.answered,
    required this.marked,
    required this.onJumpTo,
    required this.onSubmit,
    super.key,
  });

  final String title;
  final int total;
  final int index;
  final Set<int> answered;
  final Set<int> marked;
  final ValueChanged<int>? onJumpTo;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unanswered = total - answered.length;
    return SizedBox(
      key: const ValueKey('homework-navigator-panel'),
      width: BookletSize.navigatorPanel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: BorderDirectional(
            start: BorderSide(color: scheme.outlineVariant),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(BookletSpace.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: BookletSpace.s3,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const _Legend(showMarked: false),
                      HomeworkNavigatorGrid(
                        total: total,
                        index: index,
                        answered: answered,
                        marked: marked,
                        columns: 4,
                        onJumpTo: onJumpTo,
                      ),
                    ],
                  ),
                ),
              ),
              Divider(color: scheme.outlineVariant, height: BookletSpace.s5),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: BookletSpace.s3,
                children: [
                  Text(
                    '${answered.length} of $total answered · $unanswered '
                    'unanswered. You can submit once.',
                    style: theme.textTheme.bodySmall,
                  ),
                  LoadingButton(
                    label: 'Submit homework',
                    expanded: true,
                    onPressed: onSubmit == null
                        ? null
                        : () => showHomeworkSubmitDialog(
                            context,
                            total: total,
                            answered: answered,
                            onSubmit: onSubmit,
                            onJumpTo: onJumpTo,
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Phone navigator: a bottom sheet with a 6-column grid. Tapping a cell
/// closes the sheet, then jumps; Submit closes it and opens the dialog.
Future<void> showHomeworkNavigatorSheet(
  BuildContext context, {
  required String title,
  required int total,
  required int index,
  required Set<int> answered,
  required Set<int> marked,
  required ValueChanged<int>? onJumpTo,
  required VoidCallback? onSubmit,
}) => showBookletSheet<void>(
  context: context,
  builder: (sheetContext) {
    final theme = Theme.of(sheetContext);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BookletSpace.s4,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const _Legend(showMarked: true),
        HomeworkNavigatorGrid(
          total: total,
          index: index,
          answered: answered,
          marked: marked,
          columns: 6,
          onJumpTo: onJumpTo == null
              ? null
              : (i) {
                  Navigator.of(sheetContext).pop();
                  onJumpTo(i);
                },
        ),
        LoadingButton(
          label: 'Submit homework',
          expanded: true,
          variant: BookletButtonVariant.secondary,
          onPressed: onSubmit == null
              ? null
              : () {
                  Navigator.of(sheetContext).pop();
                  if (!context.mounted) return;
                  unawaited(
                    showHomeworkSubmitDialog(
                      context,
                      total: total,
                      answered: answered,
                      onSubmit: onSubmit,
                      onJumpTo: onJumpTo,
                    ),
                  );
                },
        ),
      ],
    );
  },
);
