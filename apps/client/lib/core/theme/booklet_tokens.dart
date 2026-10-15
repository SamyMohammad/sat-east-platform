import 'package:flutter/widgets.dart';

/// Spacing scale, 4-pt (Foundations.dc.html "space.*").
abstract final class BookletSpace {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
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

  /// Choice tile min height, SPR field height, keypad key height.
  static const double largeControl = 56;
  static const double choiceBadge = 28;
  static const double sprInputWidth = 200;
  static const double sprPreviewWidth = 128;
  static const double iconSmall = 20;
  static const double iconStatus = 18;
  static const double spinner = 20;
  static const double progressThickness = 4;
  static const double progressSegmentGap = 3;
  static const double headerProgress = 300;
  static const double statusIcon = 32;
  static const double chipVisual = 32;
  static const double dialogWidth = 400;
  static const double skeletonLabel = 12;
  static const double skeletonBody = 20;
  static const double skeletonLabelFraction = 0.3;
  static const double skeletonLongFraction = 0.85;
  static const double skeletonShortFraction = 0.6;
  static const double readingColumn = 640;
  static const double questionColumn = 720;
  static const double shellRail = 80;
  static const double shellSidebar = 256;
  static const double shellCompactHeader = 56;
  static const double shellMediumHeader = 64;
  static const double shellExpandedHeader = 72;
  static const double shellCompactMonogram = 32;
  static const double shellMonogram = 40;
  static const double shellNavigation = 80;
  static const double blockMathMinHeight = 64;
  static const double footerHeight = 72;
  static const double marginNote = 300;
  static const double navigatorPanel = 280;
  static const double galleryPicker = 280;
  static const double navigatorPopover = 456;
  static const int navigatorSheetColumns = 6;
  static const int navigatorPopoverColumns = 7;
  static const double navigatorCell = 48;
  static const double navigatorUnderlineWidth = 20;
  static const double navigatorUnderlineHeight = 3;
  static const double legendSwatch = 16;
  static const double submitChipMinWidth = 56;
  static const double examBarCompact = 56;
  static const double examBarWide = 76;
  static const double examBudgetCompact = 96;
  static const double examBudgetWide = 200;
  static const double examBudgetThinThickness = 3;
  static const double examToggleHeight = 40;
  static const double examTimerButtonHeight = 32;
  static const double examQuestionBadge = 32;
  static const double warningBannerMinHeight = 56;
}

/// Letter-spacing in logical px for the 12 px caption style
/// (`labelSmall` is 0.06 em = 0.72; uppercase panel titles are 0.08 em).
abstract final class BookletTracking {
  static const double caps = 0.96;
}

/// Line widths (Components.dc.html borders, outlines, strike).
abstract final class BookletStroke {
  static const double thin = 1;
  static const double badge = 1.5;
  static const double current = 2.5;
  static const double strong = 2;
  static const double strike = 1.5;
  static const double focusRing = 2;
  static const double focusGap = 2;
  static const double dash = 4;
  static const double dashGap = 3;
}

/// Opacity roles.
abstract final class BookletOpacity {
  /// Text of a crossed-out choice.
  static const double eliminated = 0.6;
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
