import 'package:flutter/widgets.dart';

import 'package:sat_east_client/core/theme/app_motion.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';

/// Deprecated shim: use App* tokens.
abstract final class BookletSpace {
  static const double s1 = AppSpace.s1;
  static const double s2 = AppSpace.s2;
  static const double s3 = AppSpace.s3;
  static const double s4 = AppSpace.s4;
  static const double s5 = AppSpace.s5;
  static const double s6 = AppSpace.s6;
  static const double s8 = AppSpace.s8;
  static const double s12 = AppSpace.s12;
  static const double s16 = AppSpace.s16;
}

/// Deprecated shim: use App* tokens.
abstract final class BookletRadius {
  static const double none = AppRadius.none;
  static const double xs = AppRadius.card;
  static const double sm = AppRadius.control;
  static const double md = AppRadius.card;
}

/// Deprecated shim: use App* tokens.
abstract final class BookletSize {
  static const double touchTarget = AppSize.touchTarget;
  static const double largeControl = AppSize.largeControl;
  static const double choiceBadge = AppSize.choiceBadge;
  static const double sprInputWidth = AppSize.sprInputWidth;
  static const double sprPreviewWidth = AppSize.sprPreviewWidth;
  static const double iconSmall = AppSize.iconSmall;
  static const double iconStatus = AppSize.iconStatus;
  static const double spinner = AppSize.spinner;
  static const double progressThickness = AppSize.progressThickness;
  static const double progressSegmentGap = AppSize.progressSegmentGap;
  static const double headerProgress = AppSize.headerProgress;
  static const double statusIcon = AppSize.statusIcon;
  static const double chipVisual = AppSize.chipVisual;
  static const double dialogWidth = AppSize.dialogWidth;
  static const double authCard = AppSize.authCard;
  static const double skeletonLabel = AppSize.skeletonLabel;
  static const double skeletonBody = AppSize.skeletonBody;
  static const double skeletonLabelFraction = AppSize.skeletonLabelFraction;
  static const double skeletonLongFraction = AppSize.skeletonLongFraction;
  static const double skeletonShortFraction = AppSize.skeletonShortFraction;
  static const double readingColumn = AppSize.readingColumn;
  static const double questionColumn = AppSize.questionColumn;
  static const double shellRail = AppSize.shellRail;
  static const double shellSidebar = AppSize.shellSidebar;
  static const double shellCompactHeader = AppSize.shellCompactHeader;
  static const double shellMediumHeader = AppSize.shellMediumHeader;
  static const double shellExpandedHeader = AppSize.shellExpandedHeader;
  static const double shellCompactMonogram = AppSize.shellCompactMonogram;
  static const double shellMonogram = AppSize.shellMonogram;
  static const double shellNavigation = AppSize.shellNavigation;
  static const double blockMathMinHeight = AppSize.blockMathMinHeight;
  static const double footerHeight = AppSize.footerHeight;
  static const double marginNote = AppSize.marginNote;
  static const double navigatorPanel = AppSize.navigatorPanel;
  static const double galleryPicker = AppSize.galleryPicker;
  static const double navigatorPopover = AppSize.navigatorPopover;
  static const int navigatorSheetColumns = AppSize.navigatorSheetColumns;
  static const int navigatorPopoverColumns = AppSize.navigatorPopoverColumns;
  static const double navigatorCell = AppSize.navigatorCell;
  static const double navigatorUnderlineWidth = AppSize.navigatorUnderlineWidth;
  static const double navigatorUnderlineHeight =
      AppSize.navigatorUnderlineHeight;
  static const double legendSwatch = AppSize.legendSwatch;
  static const double submitChipMinWidth = AppSize.submitChipMinWidth;
  static const double examBarCompact = AppSize.examBarCompact;
  static const double examBarWide = AppSize.examBarWide;
  static const double examBudgetCompact = AppSize.examBudgetCompact;
  static const double examBudgetWide = AppSize.examBudgetWide;
  static const double examBudgetThinThickness = AppSize.examBudgetThinThickness;
  static const double examToggleHeight = AppSize.examToggleHeight;
  static const double examTimerButtonHeight = AppSize.examTimerButtonHeight;
  static const double examQuestionBadge = AppSize.examQuestionBadge;
  static const double warningBannerMinHeight = AppSize.warningBannerMinHeight;
}

/// Deprecated shim: use App* tokens.
abstract final class BookletTracking {
  static const double caps = AppTracking.caps;
}

/// Deprecated shim: use App* tokens.
abstract final class BookletStroke {
  static const double thin = AppStroke.thin;
  static const double badge = AppStroke.badge;
  static const double current = AppStroke.current;
  static const double strong = AppStroke.strong;
  static const double strike = AppStroke.strike;
  static const double focusRing = AppStroke.focusRing;
  static const double focusGap = AppStroke.focusGap;
  static const double dash = AppStroke.dash;
  static const double dashGap = AppStroke.dashGap;
}

/// Deprecated shim: use App* tokens.
abstract final class BookletOpacity {
  static const double eliminated = AppOpacity.eliminated;
}

/// Deprecated shim: use App* tokens.
typedef BookletLayout = AppLayout;

/// Deprecated shim: use App* tokens.
abstract final class BookletMotion {
  static const Duration fast = AppMotion.press;
  static const Duration base = AppMotion.state;
  static const Duration slow = AppMotion.enter;
  static const Curve standard = AppMotion.standard;
  static const Curve enter = AppMotion.emphasized;
  static const Curve exit = AppMotion.standard;
  static Duration resolve(BuildContext context, Duration duration) =>
      AppMotion.resolve(context, duration);
}
