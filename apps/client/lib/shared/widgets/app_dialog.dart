import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';

class AppDialog extends StatelessWidget {
  const AppDialog({
    required this.title,
    required this.content,
    super.key,
    this.actions = const [],
  });

  final String title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    constraints: const BoxConstraints(maxWidth: AppSize.dialogWidth),
    insetPadding: const EdgeInsets.all(AppSpace.s4),
    titlePadding: const EdgeInsets.fromLTRB(
      AppSpace.s6,
      AppSpace.s6,
      AppSpace.s6,
      AppSpace.s3,
    ),
    contentPadding: const EdgeInsets.fromLTRB(
      AppSpace.s6,
      0,
      AppSpace.s6,
      AppSpace.s3,
    ),
    actionsPadding: const EdgeInsets.fromLTRB(
      AppSpace.s6,
      AppSpace.s2,
      AppSpace.s6,
      AppSpace.s6,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.overlay),
      side: BorderSide(color: context.appColors.line),
    ),
    title: Text(title, style: Theme.of(context).textTheme.titleLarge),
    content: DefaultTextStyle.merge(
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: context.appColors.inkSecondary,
      ),
      child: content,
    ),
    actions: actions,
  );
}
