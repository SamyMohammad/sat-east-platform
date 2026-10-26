import 'package:flutter/material.dart';
import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/shared/widgets/app_illustration.dart';
import 'package:sat_east_client/shared/widgets/app_shell/shell_header.dart';

/// A bounded auth surface with scrollable content and pinned primary actions.
class AppAuthCard extends StatelessWidget {
  const AppAuthCard({
    required this.children,
    super.key,
    this.footer,
    this.illustration,
  });

  final List<Widget> children;
  final Widget? footer;
  final AppIllustrationName? illustration;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.appColors.background,
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSize.authCard),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.s4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: AppSpace.s3,
                          children: [
                            const ShellWordmark(padding: EdgeInsets.zero),
                            if (illustration case final name?)
                              AppIllustration(name),
                            ...children,
                          ],
                        ),
                      ),
                    ),
                    if (footer case final pinned?)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpace.s4),
                        child: pinned,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
