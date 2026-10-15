import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/booklet_colors.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';

Future<T?> showBookletDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) => showDialog<T>(
  context: context,
  barrierDismissible: barrierDismissible,
  animationStyle: MediaQuery.disableAnimationsOf(context)
      ? AnimationStyle.noAnimation
      : null,
  builder: builder,
);

/// A non-modal-looking popover anchored to the bottom centre (above the
/// footer). Transparent barrier: tapping outside, or Esc, dismisses it.
Future<T?> showBookletPopover<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  required double width,
  required double bottomOffset,
  required String barrierLabel,
}) => showDialog<T>(
  context: context,
  barrierColor: Colors.transparent,
  barrierLabel: barrierLabel,
  animationStyle: MediaQuery.disableAnimationsOf(context)
      ? AnimationStyle.noAnimation
      : null,
  builder: (popoverContext) {
    final scheme = Theme.of(popoverContext).colorScheme;
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
              shadowColor: popoverContext.booklet.overlayShadow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(BookletRadius.md),
                side: BorderSide(color: scheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  BookletSpace.s5,
                  BookletSpace.s4,
                  BookletSpace.s5,
                  BookletSpace.s5,
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

Future<T?> showBookletSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) => showModalBottomSheet<T>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  showDragHandle: true,
  sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
      ? AnimationStyle.noAnimation
      : null,
  builder: (modalContext) => Padding(
    padding: EdgeInsets.only(
      bottom: MediaQuery.viewInsetsOf(modalContext).bottom,
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          BookletSpace.s4,
          0,
          BookletSpace.s4,
          BookletSpace.s4,
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
                icon: const Icon(Icons.close),
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

ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showBookletSnackBar({
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
              textColor: Theme.of(context).colorScheme.inversePrimary,
            )
          : null,
    ),
    snackBarAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : null,
  );
}
