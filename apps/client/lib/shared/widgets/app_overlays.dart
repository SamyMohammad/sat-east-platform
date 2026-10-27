import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_motion.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';

Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) => showDialog<T>(
  context: context,
  barrierDismissible: barrierDismissible,
  animationStyle: _overlayMotion(context),
  builder: builder,
);

/// A non-modal-looking popover anchored to the bottom centre (above the
/// footer). Transparent barrier: tapping outside, or Esc, dismisses it.
Future<T?> showAppPopover<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  required double width,
  required double bottomOffset,
  required String barrierLabel,
}) => showDialog<T>(
  context: context,
  barrierColor: context.appColors.scrim.withValues(alpha: 0),
  barrierLabel: barrierLabel,
  animationStyle: _overlayMotion(context),
  builder: (popoverContext) {
    final scheme = popoverContext.appColors;
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomOffset),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width),
            child: Material(
              color: scheme.surface,
              elevation: Theme.of(popoverContext).dialogTheme.elevation ?? 0,
              shadowColor: popoverContext.appColors.shadow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.overlay),
                side: BorderSide(color: scheme.line),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.s5,
                  AppSpace.s4,
                  AppSpace.s5,
                  AppSpace.s5,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: SingleChildScrollView(
                        child: Builder(builder: builder),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  },
);

Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) => showModalBottomSheet<T>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  showDragHandle: true,
  sheetAnimationStyle: _overlayMotion(context),
  builder: (modalContext) => Padding(
    padding: EdgeInsets.only(
      bottom: MediaQuery.viewInsetsOf(modalContext).bottom,
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s4,
          0,
          AppSpace.s4,
          AppSpace.s4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: IconButton(
                tooltip: 'Close sheet',
                onPressed: () => Navigator.of(modalContext).pop(),
                icon: const Icon(AppIcons.close),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(child: Builder(builder: builder)),
            ),
          ],
        ),
      ),
    ),
  ),
);

ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showAppSnackBar({
  required BuildContext context,
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  assert(
    (actionLabel == null) == (onAction == null),
    'Provide both actionLabel and onAction, or neither.',
  );
  return ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      action: actionLabel != null && onAction != null
          ? SnackBarAction(
              label: actionLabel,
              onPressed: onAction,
              textColor: context.appColors.brandLine,
            )
          : null,
    ),
    snackBarAnimationStyle: _overlayMotion(context),
  );
}

AnimationStyle _overlayMotion(BuildContext context) => AnimationStyle(
  duration: AppMotion.resolve(context, AppMotion.enter),
  reverseDuration: AppMotion.resolve(context, AppMotion.state),
  curve: AppMotion.emphasized,
  reverseCurve: AppMotion.standard,
);
