import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/catalogue/presentation/catalogue_copy.dart';

class CatalogueFrame extends StatelessWidget {
  const CatalogueFrame({
    required this.fallbackLocation,
    required this.child,
    super.key,
  });

  final String fallbackLocation;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(CatalogueCopy.title),
      leading: context.canPop()
          ? const BackButton()
          : IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back',
              onPressed: () => context.go(fallbackLocation),
            ),
    ),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: BookletSize.questionColumn,
          ),
          child: child,
        ),
      ),
    ),
  );
}
