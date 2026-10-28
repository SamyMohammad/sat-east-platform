import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_motion.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/skills/domain/entities/skills_overview.dart';
import 'package:sat_east_client/features/skills/presentation/skills_copy.dart';

/// Section with the weekly trend: the line chart, or a plain sentence while
/// there is too little data for a trend (fewer than two weeks).
class MasteryTrendSection extends StatelessWidget {
  const MasteryTrendSection({
    required this.trend,
    required this.summary,
    super.key,
  });

  final List<TrendPoint> trend;
  final SkillsSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpace.s3,
      children: [
        Semantics(
          header: true,
          child: Text(
            SkillsCopy.trendTitle,
            style: theme.textTheme.titleMedium,
          ),
        ),
        if (trend.length < 2)
          Text(
            _thinCopy(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.appColors.inkSecondary,
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s4),
              child: MasteryTrendChart(points: trend),
            ),
          ),
      ],
    );
  }

  String _thinCopy() {
    final min = summary.trendMinAnswers;
    final missing = min == null ? 0 : min - summary.gradedAnswers;
    return missing > 0
        ? SkillsCopy.trendNeedsAnswers(missing)
        : SkillsCopy.trendKeepPractising;
  }
}

/// Weekly mean mastery as one line, 0-100 on the y axis, week dates on the x
/// axis and the last value labelled. Draws in once; static under reduced
/// motion.
class MasteryTrendChart extends StatefulWidget {
  const MasteryTrendChart({required this.points, super.key});

  final List<TrendPoint> points;

  @override
  State<MasteryTrendChart> createState() => _MasteryTrendChartState();
}

class _MasteryTrendChartState extends State<MasteryTrendChart>
    with SingleTickerProviderStateMixin {
  static const double _height = 200;

  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.enter);
    _progress = _controller.drive(CurveTween(curve: AppMotion.emphasized));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final duration = AppMotion.resolve(context, AppMotion.enter);
    if (duration == Duration.zero) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.duration = duration;
      unawaited(_controller.forward());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final l10n = MaterialLocalizations.of(context);
    final style =
        (Theme.of(context).textTheme.labelSmall ??
                DefaultTextStyle.of(context).style)
            .copyWith(color: colors.inkSecondary);
    final points = widget.points;
    return Semantics(
      key: const ValueKey('mastery-trend-chart'),
      image: true,
      label: SkillsCopy.trendSemantics(points),
      child: ExcludeSemantics(
        child: SizedBox(
          height: _height,
          width: double.infinity,
          child: AnimatedBuilder(
            animation: _progress,
            builder: (context, _) => CustomPaint(
              painter: _TrendPainter(
                points: points,
                labels: [
                  for (final point in points)
                    l10n.formatShortMonthDay(point.weekStart),
                ],
                progress: _progress.value,
                lineColor: colors.brand,
                gridColor: colors.line,
                surface: colors.raised,
                labelStyle: style,
                valueStyle: style.copyWith(
                  color: colors.ink,
                  fontWeight: FontWeight.w600,
                ),
                textScaler: MediaQuery.textScalerOf(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({
    required this.points,
    required this.labels,
    required this.progress,
    required this.lineColor,
    required this.gridColor,
    required this.surface,
    required this.labelStyle,
    required this.valueStyle,
    required this.textScaler,
  });

  final List<TrendPoint> points;
  final List<String> labels;
  final double progress;
  final Color lineColor;
  final Color gridColor;
  final Color surface;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final TextScaler textScaler;

  static const double _gap = 8;
  static const double _dot = 4;

  TextPainter _text(String text, TextStyle style) => TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final yLabels = [
      for (final v in const [0, 50, 100]) _text('$v', labelStyle),
    ];
    final xLabels = [for (final l in labels) _text(l, labelStyle)];
    final yLabelWidth = yLabels.map((p) => p.width).reduce(math.max);
    final xLabelHeight = xLabels.map((p) => p.height).reduce(math.max);
    final valueLabel = _text(
      points.last.mastery.round().toString(),
      valueStyle,
    );
    final plot = Rect.fromLTRB(
      yLabelWidth + _gap,
      valueLabel.height + _dot + 2,
      size.width - valueLabel.width / 2 - _dot,
      size.height - xLabelHeight - _gap,
    );
    if (plot.width <= 0 || plot.height <= 0) return;

    double yFor(double v) =>
        plot.bottom - plot.height * (v.clamp(0, 100) / 100);

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = AppStroke.thin;
    for (final (i, value) in const [0, 50, 100].indexed) {
      final y = yFor(value.toDouble());
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      yLabels[i].paint(
        canvas,
        Offset(yLabelWidth - yLabels[i].width, y - yLabels[i].height / 2),
      );
    }

    final first = points.first.weekStart;
    final span = math.max(1, points.last.weekStart.difference(first).inDays);
    final offsets = [
      for (final p in points)
        Offset(
          plot.left + plot.width * p.weekStart.difference(first).inDays / span,
          yFor(p.mastery),
        ),
    ];

    _paintXLabels(canvas, size, plot, offsets, xLabels);

    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (final o in offsets.skip(1)) {
      path.lineTo(o.dx, o.dy);
    }
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppStroke.strong
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final reach = plot.left + plot.width * progress;
    for (final (i, o) in offsets.indexed) {
      if (o.dx > reach + 0.5) continue;
      final isLast = i == offsets.length - 1;
      canvas
        ..drawCircle(o, _dot, Paint()..color = surface)
        ..drawCircle(
          o,
          _dot,
          Paint()
            ..color = lineColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = AppStroke.strong,
        );
      if (isLast) {
        valueLabel.paint(
          canvas,
          Offset(
            math.min(
              o.dx - valueLabel.width / 2,
              size.width - valueLabel.width,
            ),
            o.dy - _dot - valueLabel.height - 2,
          ),
        );
      }
    }
  }

  void _paintXLabels(
    Canvas canvas,
    Size size,
    Rect plot,
    List<Offset> offsets,
    List<TextPainter> xLabels,
  ) {
    Rect rectFor(int i) {
      final p = xLabels[i];
      final left = (offsets[i].dx - p.width / 2)
          .clamp(0.0, math.max(0.0, size.width - p.width))
          .toDouble();
      return Rect.fromLTWH(left, plot.bottom + _gap, p.width, p.height);
    }

    final lastIndex = offsets.length - 1;
    final last = rectFor(lastIndex);
    var previousRight = double.negativeInfinity;
    for (var i = 0; i < offsets.length; i++) {
      final rect = rectFor(i);
      final edge = i == 0 || i == lastIndex;
      final clear =
          rect.left > previousRight + _gap && rect.right < last.left - _gap;
      if (edge || clear) {
        xLabels[i].paint(canvas, rect.topLeft);
        previousRight = rect.right;
      }
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.progress != progress ||
      old.points != points ||
      old.labels != labels ||
      old.lineColor != lineColor ||
      old.gridColor != gridColor ||
      old.surface != surface ||
      old.labelStyle != labelStyle ||
      old.valueStyle != valueStyle ||
      old.textScaler != textScaler;
}
