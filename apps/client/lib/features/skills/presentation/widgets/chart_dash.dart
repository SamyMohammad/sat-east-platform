import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:sat_east_client/core/theme/app_tokens.dart';

/// The strong threshold to draw as a target, or null when it is missing or
/// outside 1-100 (nothing sensible to draw).
double? validStrongAt(double? value) =>
    value != null && value > 0 && value <= 100 ? value : null;

/// Strokes [path] as a dashed line; shared by the radar ring and the trend
/// target line.
void drawDashedPath(Canvas canvas, Path path, Paint paint) {
  for (final metric in path.computeMetrics()) {
    for (
      var d = 0.0;
      d < metric.length;
      d += AppStroke.dash + AppStroke.dashGap
    ) {
      canvas.drawPath(
        metric.extractPath(d, math.min(d + AppStroke.dash, metric.length)),
        paint,
      );
    }
  }
}
