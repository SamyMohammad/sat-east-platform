import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/shared/widgets/app_illustration.dart';

class CatalogueGreeting extends StatelessWidget {
  const CatalogueGreeting({super.key});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final heading = Text(
      'Your courses',
      style: Theme.of(context).textTheme.headlineLarge,
    );
    final illustration = AppIllustration(
      AppIllustrationName.welcome,
      height: wide ? 200 : 140,
    );
    return wide
        ? Row(
            children: [
              Expanded(child: heading),
              illustration,
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpace.s4,
            children: [illustration, heading],
          );
  }
}
