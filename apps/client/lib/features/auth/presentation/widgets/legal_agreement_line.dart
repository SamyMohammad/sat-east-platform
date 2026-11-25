import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/links/external_link_launcher.dart';
import 'package:sat_east_client/core/links/legal_links.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

/// "By creating an account you agree to the Terms and the Privacy Policy."
/// Both links open the landing pages outside the app.
class LegalAgreementLine extends StatelessWidget {
  const LegalAgreementLine({super.key});

  Future<void> _open(BuildContext context, Uri url) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final opened = await getIt<ExternalLinkLauncher>()(url);
    if (!opened) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Could not open the link. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final links = LegalLinks();
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpace.s1,
      children: [
        Text('By creating an account you agree to the', style: style),
        LoadingButton(
          label: 'Terms',
          variant: AppButtonVariant.tertiary,
          onPressed: () => unawaited(_open(context, links.terms)),
        ),
        Text('and the', style: style),
        LoadingButton(
          label: 'Privacy Policy',
          variant: AppButtonVariant.tertiary,
          onPressed: () => unawaited(_open(context, links.privacy)),
        ),
      ],
    );
  }
}
