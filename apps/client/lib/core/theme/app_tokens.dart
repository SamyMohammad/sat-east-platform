abstract final class AppSpace {
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

abstract final class AppRadius {
  static const double none = 0;
  static const double control = 10;
  static const double card = 12;
  static const double choice = card;
  static const double overlay = 16;
  static const double pill = 999;
}

abstract final class AppTracking {
  static const double caps = 0.96;
}

abstract final class AppStroke {
  static const double thin = 1;
  static const double badge = 1.5;
  static const double current = 2.5;
  static const double strong = 2;
  static const double strike = 1.5;
  static const double focusRing = 3;
  static const double focusGap = 2;
  static const double dash = 4;
  static const double dashGap = 3;
}

abstract final class AppOpacity {
  /// Text of a crossed-out choice.
  static const double eliminated = 0.6;
}

abstract final class AppSize {
  static const double touchTarget = 48;

  /// Min width of the practice dock's primary button on desktop.
  static const double dockPrimaryMinWidth = 180;

  /// Choice tile min height, SPR field height, keypad key height.
  static const double largeControl = 56;
  static const double choiceBadge = 30;
  static const double sprInputWidth = 200;
  static const double sprPreviewWidth = 128;
  static const double iconSmall = 20;
  static const double iconTile = 40;
  static const double illustration = 200;
  static const double iconStatus = 18;
  static const double spinner = 20;
  static const double progressThickness = 6;
  static const double progressSegmentGap = 4;
  static const double headerProgress = 360;
  static const double statusIcon = 32;
  static const double chipVisual = 32;
  static const double dialogWidth = 400;

  /// Max width of the sign-in / sign-up / device-gate card.
  static const double authCard = 400;
  static const double skeletonLabel = 12;
  static const double skeletonBody = 20;
  static const double skeletonLabelFraction = 0.3;
  static const double skeletonLongFraction = 0.85;
  static const double skeletonShortFraction = 0.6;
  static const double readingColumn = 680;
  static const double questionColumn = 720;
  static const double shellRail = 80;
  static const double shellSidebar = 232;
  static const double shellCompactHeader = 56;
  static const double shellMediumHeader = 64;
  static const double shellExpandedHeader = 64;
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

enum AppLayout {
  compact,
  medium,
  expanded;

  static AppLayout forWidth(double width) {
    if (width <= 600) return compact;
    if (width < 1024) return medium;
    return expanded;
  }
}
