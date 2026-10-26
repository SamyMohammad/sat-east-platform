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
    this.showWelcomeIllustration = false,
  });

  final List<Widget> children;
  final Widget? footer;
  final AppIllustrationName? illustration;
  final bool showWelcomeIllustration;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.appColors.background,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 960;
          final form = ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSize.authCard),
            child: _form(wide: wide),
          );
          return Padding(
            padding: const EdgeInsets.all(AppSpace.s4),
            child: Center(
              child: wide
                  ? SizedBox(
                      key: const ValueKey('auth-panes'),
                      width: 1040,
                      height: (constraints.maxHeight - AppSpace.s8).clamp(
                        0.0,
                        768.0,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Expanded(child: _AuthWelcomePane()),
                          const SizedBox(width: AppSpace.s6),
                          SizedBox(
                            width: AppSize.authCard,
                            child: Center(child: form),
                          ),
                        ],
                      ),
                    )
                  : form,
            ),
          );
        },
      ),
    ),
  );

  Widget _form({required bool wide}) => Card(
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
                  if (!wide && showWelcomeIllustration)
                    const AppIllustration(
                      AppIllustrationName.welcome,
                      height: 120,
                    ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpace.s3),
                    child: ShellWordmark(padding: EdgeInsets.zero),
                  ),
                  if (illustration case final name?) AppIllustration(name),
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
  );
}

class _AuthWelcomePane extends StatelessWidget {
  const _AuthWelcomePane();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: const ValueKey('auth-welcome-pane'),
    decoration: BoxDecoration(
      color: context.appColors.brandWash,
      borderRadius: BorderRadius.circular(AppRadius.overlay),
    ),
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.s8 + AppSpace.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ShellWordmark(padding: EdgeInsets.zero),
                  const SizedBox(height: AppSpace.s6),
                  Text(
                    'Build confidence, one topic at a time.',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s6),
          const Flexible(
            child: AppIllustration(AppIllustrationName.welcome, height: 280),
          ),
        ],
      ),
    ),
  );
}
