import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:sat_east_client/core/widgets/app_shell/app_shell_destination.dart';

double maxShellLabelHeight(
  BuildContext context,
  TextStyle style,
  double width,
  TextScaler scaler,
) {
  var height = 0.0;
  for (final destination in AppShellDestination.values) {
    final painter = TextPainter(
      text: TextSpan(
        text: destination.label,
        style: style.copyWith(fontWeight: FontWeight.w700),
      ),
      textDirection: Directionality.of(context),
      textScaler: scaler,
    )..layout(maxWidth: width);
    height = math.max(height, painter.height);
    painter.dispose();
  }
  return height;
}
