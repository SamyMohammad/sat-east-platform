import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/catalogue/presentation/catalogue_copy.dart';

class CatalogueFrame extends StatelessWidget {
  const CatalogueFrame({
    required this.fallbackLocation,
    required this.child,
    super.key,
    this.showTitle = true,
  });

  final String fallbackLocation;
  final Widget child;

  /// The catalogue list has its own H1, so its bar stays untitled.
  final bool showTitle;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: showTitle ? const Text(CatalogueCopy.title) : null,
      leading: context.canPop()
          ? const BackButton()
          : IconButton(
              icon: const Icon(AppIcons.back),
              tooltip: 'Back',
              onPressed: () => context.go(fallbackLocation),
            ),
    ),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSize.questionColumn,
          ),
          child: child,
        ),
      ),
    ),
  );
}
