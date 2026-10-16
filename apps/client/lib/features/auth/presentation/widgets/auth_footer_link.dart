import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

/// "Prompt  Link" footer that navigates with `context.go`.
class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({
    required this.prompt,
    required this.linkLabel,
    required this.path,
    super.key,
  });

  final String prompt;
  final String linkLabel;
  final String path;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: BookletSpace.s1,
    children: [
      Text(prompt, style: Theme.of(context).textTheme.bodyMedium),
      LoadingButton(
        label: linkLabel,
        variant: BookletButtonVariant.tertiary,
        onPressed: () => context.go(path),
      ),
    ],
  );
}
