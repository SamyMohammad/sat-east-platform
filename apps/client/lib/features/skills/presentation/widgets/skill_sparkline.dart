import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/skills/domain/entities/skills_overview.dart';
import 'package:sat_east_client/features/skills/presentation/skills_copy.dart';

/// Smallest vertical span (in mastery points) a sparkline is scaled to, so a
/// two-point wobble does not look like a cliff.
const double sparklineMinSpan = 10;

/// The (min, max) mastery a sparkline is scaled between: the data's own range,
/// widened around its middle to at least [sparklineMinSpan].
(double, double) sparklineRange(List<double> values) {
  var min = values.reduce((a, b) => a < b ? a : b);
  var max = values.reduce((a, b) => a > b ? a : b);
  if (max - min < sparklineMinSpan) {
    final mid = (min + max) / 2;
    min = mid - sparklineMinSpan / 2;
    max = mid + sparklineMinSpan / 2;
  }
  return (min, max);
}

/// Sparkline plus its change in text ("▲ 12"): icon and number, never colour
/// alone. Shown once a skill has two weeks of history.
class SkillTrendMini extends StatelessWidget {
  const SkillTrendMini({required this.history, super.key});

  final List<TrendPoint> history;

  @override
  Widget build(BuildContext context) {
    final delta = history.spanDelta;
    if (delta == null) return const SizedBox.shrink();
    final colors = context.appColors;
    final icon = switch (delta) {
      0 => AppIcons.trendFlat,
      > 0 => AppIcons.moveUp,
      _ => AppIcons.moveDown,
    };
    return Row(
      key: const ValueKey('skill-trend-mini'),
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpace.s1,
      children: [
        SkillSparkline(history: history),
        Icon(icon, size: AppSize.iconStatus - 4, color: colors.inkSecondary),
        Text(
          SkillsCopy.sparkDelta(delta),
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: colors.inkSecondary),
        ),
      ],
    );
  }
}

/// Tiny weekly-mastery line of one skill, scaled to its own range; the last
/// point is a filled dot. Purely visual: the row's text carries the numbers.
/// Raw geometry of the sparkline, in logical pixels.
abstract final class _SparkGeometry {
  /// Overall box; small enough to sit beside a mastery bar.
  static const double width = 56;
  static const double height = 20;

  /// Radius of the end dot; the line is inset by it so the dot is not cut.
  static const double dot = 3;
}

class SkillSparkline extends StatelessWidget {
  const SkillSparkline({required this.history, super.key});

  final List<TrendPoint> history;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return ExcludeSemantics(
      child: CustomPaint(
        size: const Size(_SparkGeometry.width, _SparkGeometry.height),
        painter: _SparklinePainter(history: history, color: colors.brand),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({required this.history, required this.color});

  final List<TrendPoint> history;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (history.length < 2) return;
    const left = _SparkGeometry.dot;
    final right = size.width - _SparkGeometry.dot;
    const top = _SparkGeometry.dot;
    final bottom = size.height - _SparkGeometry.dot;
    final (low, high) = sparklineRange([for (final p in history) p.mastery]);
    final first = history.first.weekStart;
    final span = history.last.weekStart.difference(first).inDays;
    final offsets = [
      for (final (i, p) in history.indexed)
        Offset(
          span <= 0
              ? left + (right - left) * i / (history.length - 1)
              : left +
                    (right - left) *
                        p.weekStart.difference(first).inDays /
                        span,
          bottom - (bottom - top) * ((p.mastery - low) / (high - low)),
        ),
    ];
    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (final o in offsets.skip(1)) {
      path.lineTo(o.dx, o.dy);
    }
    canvas
      ..drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = AppStroke.strong
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawCircle(offsets.last, _SparkGeometry.dot, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.history != history || old.color != color;
}
