import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/booklet_colors.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/shared/widgets/booklet_dialog.dart';
import 'package:sat_east_client/shared/widgets/booklet_overlays.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

/// Blocking dialog shown when the quiz clock reaches zero. Closes any open
/// popover, sheet or dialog first so exactly one dialog is on screen, and
/// cannot be dismissed except through Continue. Call once per attempt: the
/// Cubit owns the once-only event.
Future<void> showQuizTimeUpDialog(
  BuildContext context, {
  required String title,
  required int answered,
  required VoidCallback onContinue,
}) {
  // Sheets live on the nearest navigator; dialogs and popovers on the root.
  Navigator.of(context).popUntil((route) => route is! PopupRoute);
  Navigator.of(
    context,
    rootNavigator: true,
  ).popUntil((route) => route is! PopupRoute);
  final body = answered == 1
      ? 'Your 1 answer was saved and submitted automatically.'
      : 'Your $answered answers were saved and submitted automatically.';
  return showBookletDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => PopScope(
      canPop: false,
      child: BookletDialog(
        title: "Time's up. $title submitted.",
        // BookletDialog has no icon slot (title/content/actions only).
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: BookletSpace.s3,
          children: [
            Icon(
              AppIcons.time,
              size: BookletSize.statusIcon,
              color: dialogContext.booklet.warning,
            ),
            Text('$body Unanswered questions count as incorrect.'),
          ],
        ),
        actions: [
          LoadingButton(
            label: 'Continue',
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onContinue();
            },
          ),
        ],
      ),
    ),
  );
}
