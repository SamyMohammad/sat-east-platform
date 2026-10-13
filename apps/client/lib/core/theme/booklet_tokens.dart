import 'package:flutter/widgets.dart';

/// Spacing scale, 4-pt (Foundations.dc.html "space.*").
abstract final class BookletSpace {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s6 = 24;
  static const double s8 = 32;
  static const double s12 = 48;
  static const double s16 = 64;
}

/// Corner radii (Foundations.dc.html "radius.*").
abstract final class BookletRadius {
  static const double none = 0;
  static const double xs = 2;
  static const double sm = 4;
  static const double md = 8;
}

/// Fixed sizes shared by many widgets.
abstract final class BookletSize {
  static const double touchTarget = 48;
  static const double readingColumn = 640;
  static const double questionColumn = 720;
  static const double blockMathMinHeight = 64;
}

/// App shell layouts: bottom nav, rail, sidebar (App Shell.dc.html).
enum BookletLayout {
  compact,
  medium,
  expanded;

  static BookletLayout forWidth(double width) {
    if (width <= 600) return compact;
    if (width < 1024) return medium;
    return expanded;
  }
}

/// Motion tokens (Foundations.dc.html "motion.*"). No bounce or spring.
abstract final class BookletMotion {
  static const Duration fast = Duration(milliseconds: 100);
  static const Duration base = Duration(milliseconds: 180);
  static const Duration slow = Duration(milliseconds: 280);

  static const Curve standard = Cubic(0.2, 0, 0, 1);
  static const Curve enter = Cubic(0.05, 0.7, 0.1, 1);
  static const Curve exit = Cubic(0.3, 0, 0.8, 0.15);

  /// Applies reduced motion: slow → instant, base → fast fade.
  static Duration resolve(BuildContext context, Duration duration) {
    if (!MediaQuery.disableAnimationsOf(context)) return duration;
    if (duration >= slow) return Duration.zero;
    return duration > fast ? fast : duration;
  }
}
