import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/booklet_tokens.dart';

class BookletSkeleton extends StatelessWidget {
  const BookletSkeleton({super.key, this.label = 'Loading content'});

  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _bar(
            context,
            BookletSize.skeletonLabel,
            fraction: BookletSize.skeletonLabelFraction,
          ),
          const SizedBox(height: BookletSpace.s3),
          _bar(
            context,
            BookletSize.skeletonBody,
            fraction: BookletSize.skeletonLongFraction,
          ),
          const SizedBox(height: BookletSpace.s3),
          _bar(
            context,
            BookletSize.skeletonBody,
            fraction: BookletSize.skeletonShortFraction,
          ),
          const SizedBox(height: BookletSpace.s4),
          _bar(context, BookletSize.largeControl, radius: BookletRadius.sm),
          const SizedBox(height: BookletSpace.s3),
          _bar(context, BookletSize.largeControl, radius: BookletRadius.sm),
        ],
      ),
    ),
  );

  Widget _bar(
    BuildContext context,
    double height, {
    double fraction = 1,
    double radius = BookletRadius.xs,
  }) => FractionallySizedBox(
    alignment: AlignmentDirectional.centerStart,
    widthFactor: fraction,
    child: Container(
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(radius),
      ),
    ),
  );
}
