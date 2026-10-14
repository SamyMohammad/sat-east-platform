import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/booklet_tokens.dart';

class BookletDialog extends StatelessWidget {
  const BookletDialog({
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
    constraints: const BoxConstraints(maxWidth: BookletSize.dialogWidth),
    insetPadding: const EdgeInsets.all(BookletSpace.s4),
    titlePadding: const EdgeInsets.fromLTRB(
      BookletSpace.s6,
      BookletSpace.s6,
      BookletSpace.s6,
      BookletSpace.s3,
    ),
    contentPadding: const EdgeInsets.fromLTRB(
      BookletSpace.s6,
      0,
      BookletSpace.s6,
      BookletSpace.s3,
    ),
    actionsPadding: const EdgeInsets.fromLTRB(
      BookletSpace.s6,
      BookletSpace.s2,
      BookletSpace.s6,
      BookletSpace.s6,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(BookletRadius.md),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    title: Text(title, style: Theme.of(context).textTheme.titleLarge),
    content: DefaultTextStyle.merge(
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      child: content,
    ),
    actions: actions,
  );
}
