import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_hues.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/core/theme/app_type.dart';

/// A hue tile, sized like an `IconTile`, that shows the topic number ("1.1")
/// instead of an icon so every topic reads differently at a glance.
class TopicNumberTile extends StatelessWidget {
  const TopicNumberTile(this.number, {this.hue = SubjectHue.blue, super.key});

  final String number;
  final SubjectHue hue;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: AppSize.iconTile,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: hue.wash(Theme.of(context).brightness),
        borderRadius: const BorderRadius.all(
          Radius.circular(AppRadius.control),
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s1),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              number,
              maxLines: 1,
              textScaler: TextScaler.noScaling,
              textDirection: TextDirection.ltr,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: context.appColors.ink,
                fontWeight: FontWeight.w600,
                fontFeatures: AppType.count.fontFeatures,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
