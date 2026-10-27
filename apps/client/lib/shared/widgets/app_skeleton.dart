import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_motion.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';

class AppSkeleton extends StatelessWidget {
  const AppSkeleton({super.key, this.label = 'Loading content'});

  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: AppMotion.resolve(context, AppMotion.signature),
        curve: AppMotion.standard,
        builder: (context, sweep, child) => AppMotion.reduced(context)
            ? child!
            : ShaderMask(
                blendMode: BlendMode.srcATop,
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment(-3 + sweep * 6, 0),
                  end: Alignment(-1 + sweep * 6, 0),
                  colors: [
                    context.appColors.line.withValues(alpha: 0),
                    context.appColors.raised,
                    context.appColors.line.withValues(alpha: 0),
                  ],
                  stops: const [0, .5, 1],
                ).createShader(bounds),
                child: child,
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _bar(
              context,
              AppSize.skeletonLabel,
              fraction: AppSize.skeletonLabelFraction,
            ),
            const SizedBox(height: AppSpace.s3),
            _bar(
              context,
              AppSize.skeletonBody,
              fraction: AppSize.skeletonLongFraction,
            ),
            const SizedBox(height: AppSpace.s3),
            _bar(
              context,
              AppSize.skeletonBody,
              fraction: AppSize.skeletonShortFraction,
            ),
            const SizedBox(height: AppSpace.s4),
            _bar(context, AppSize.largeControl, radius: AppRadius.control),
            const SizedBox(height: AppSpace.s3),
            _bar(context, AppSize.largeControl, radius: AppRadius.control),
          ],
        ),
      ),
    ),
  );

  Widget _bar(
    BuildContext context,
    double height, {
    double fraction = 1,
    double radius = AppRadius.card,
  }) => FractionallySizedBox(
    alignment: AlignmentDirectional.centerStart,
    widthFactor: fraction,
    child: Container(
      height: height,
      decoration: BoxDecoration(
        color: context.appColors.line,
        borderRadius: BorderRadius.circular(radius),
      ),
    ),
  );
}
