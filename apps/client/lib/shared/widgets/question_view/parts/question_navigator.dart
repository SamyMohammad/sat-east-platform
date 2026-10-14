import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/shared/widgets/booklet_overlays.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';
import 'package:sat_east_client/shared/widgets/painters/dashed_border.dart';

/// Grid of numbered question cells: current, answered, unanswered, marked.
/// Built eagerly (a homework or quiz has tens of questions, not thousands).
class QuestionNavigatorGrid extends StatelessWidget {
  const QuestionNavigatorGrid({
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

/// Legend shared by the sheet, the popover and the wide panel.
class NavigatorLegend extends StatelessWidget {
  const NavigatorLegend({super.key});

  @override
  Widget build(BuildContext context) => const Wrap(
    spacing: BookletSpace.s4,
    runSpacing: BookletSpace.s2,
    children: [
      _LegendItem(_Swatch.current, 'Current'),
      _LegendItem(_Swatch.answered, 'Answered'),
      _LegendItem(_Swatch.unanswered, 'Unanswered'),
      _LegendItem(_Swatch.marked, 'Marked for review'),
    ],
  );
}

/// Navigator content shared by the phone sheet and the wide popover.
class _NavigatorContent extends StatelessWidget {
  const _NavigatorContent({
    required this.overlayContext,
    required this.hostContext,
    required this.title,
    required this.total,
    required this.index,
    required this.answered,
    required this.marked,
    required this.columns,
    required this.onJumpTo,
    required this.submitLabel,
    required this.onSubmitPressed,
    required this.showClose,
  });

  final BuildContext overlayContext;
  final BuildContext hostContext;
  final String title;
  final int total;
  final int index;
  final Set<int> answered;
  final Set<int> marked;
  final int columns;
  final ValueChanged<int>? onJumpTo;
  final String submitLabel;
  final VoidCallback? onSubmitPressed;
  final bool showClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BookletSpace.s4,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (showClose)
              IconButton(
                tooltip: 'Close navigator',
                onPressed: () => Navigator.of(overlayContext).pop(),
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        const NavigatorLegend(),
        Divider(color: scheme.outlineVariant, height: 0),
        QuestionNavigatorGrid(
          total: total,
          index: index,
          answered: answered,
          marked: marked,
          columns: columns,
          onJumpTo: onJumpTo == null
              ? null
              : (i) {
                  Navigator.of(overlayContext).pop();
                  onJumpTo!(i);
                },
        ),
        LoadingButton(
          label: submitLabel,
          expanded: true,
          variant: BookletButtonVariant.secondary,
          onPressed: onSubmitPressed == null
              ? null
              : () {
                  Navigator.of(overlayContext).pop();
                  if (!hostContext.mounted) return;
                  onSubmitPressed!();
                },
        ),
      ],
    );
  }
}

/// Phone navigator: a bottom sheet with a 6-column grid. Tapping a cell
/// closes the sheet, then jumps; the submit button closes it, then calls
/// [onSubmitPressed].
Future<void> showNavigatorSheet(
  BuildContext context, {
  required String title,
  required int total,
  required int index,
  required Set<int> answered,
  required Set<int> marked,
  required ValueChanged<int>? onJumpTo,
  required String submitLabel,
  required VoidCallback? onSubmitPressed,
}) => showBookletSheet<void>(
  context: context,
  builder: (sheetContext) => _NavigatorContent(
    overlayContext: sheetContext,
    hostContext: context,
    title: title,
    total: total,
    index: index,
    answered: answered,
    marked: marked,
    columns: BookletSize.navigatorSheetColumns,
    onJumpTo: onJumpTo,
    submitLabel: submitLabel,
    onSubmitPressed: onSubmitPressed,
    showClose: false,
  ),
);

/// Wide navigator: a popover above the footer with a 7-column grid.
Future<void> showNavigatorPopover(
  BuildContext context, {
  required String title,
  required int total,
  required int index,
  required Set<int> answered,
  required Set<int> marked,
  required ValueChanged<int>? onJumpTo,
  required String submitLabel,
  required VoidCallback? onSubmitPressed,
}) => showBookletPopover<void>(
  context: context,
  width: BookletSize.navigatorPopover,
  bottomOffset: BookletSize.footerHeight + BookletSpace.s3,
  barrierLabel: 'Close navigator',
  builder: (popoverContext) => _NavigatorContent(
    overlayContext: popoverContext,
    hostContext: context,
    title: title,
    total: total,
    index: index,
    answered: answered,
    marked: marked,
    columns: BookletSize.navigatorPopoverColumns,
    onJumpTo: onJumpTo,
    submitLabel: submitLabel,
    onSubmitPressed: onSubmitPressed,
    showClose: true,
  ),
);
