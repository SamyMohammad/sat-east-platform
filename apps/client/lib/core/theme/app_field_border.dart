import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_tokens.dart';

/// Rounded full-outline field border that is not an "outline" border to the
/// input decorator, so a floating label sits inside the box above the value
/// instead of cutting a notch into the top edge.
class AppFieldBorder extends UnderlineInputBorder {
  const AppFieldBorder({
    super.borderSide = const BorderSide(),
    super.borderRadius = const BorderRadius.all(
      Radius.circular(AppRadius.control),
    ),
  });

  @override
  AppFieldBorder copyWith({
    BorderSide? borderSide,
    BorderRadius? borderRadius,
  }) => AppFieldBorder(
    borderSide: borderSide ?? this.borderSide,
    borderRadius: borderRadius ?? this.borderRadius,
  );

  @override
  AppFieldBorder scale(double t) => AppFieldBorder(
    borderSide: borderSide.scale(t),
    borderRadius: borderRadius,
  );

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path()
    ..addRRect(
      borderRadius
          .resolve(textDirection)
          .toRRect(rect)
          .deflate(borderSide.width),
    );

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(borderRadius.resolve(textDirection).toRRect(rect));

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is AppFieldBorder) {
      return AppFieldBorder(
        borderSide: BorderSide.lerp(a.borderSide, borderSide, t),
        borderRadius: BorderRadius.lerp(a.borderRadius, borderRadius, t)!,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is AppFieldBorder) {
      return AppFieldBorder(
        borderSide: BorderSide.lerp(borderSide, b.borderSide, t),
        borderRadius: BorderRadius.lerp(borderRadius, b.borderRadius, t)!,
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0.0,
    double gapPercentage = 0.0,
    TextDirection? textDirection,
  }) {
    if (borderSide.style == BorderStyle.none) return;
    canvas.drawRRect(
      borderRadius
          .resolve(textDirection)
          .toRRect(rect)
          .deflate(borderSide.width / 2),
      borderSide.toPaint(),
    );
  }
}
