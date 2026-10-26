import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_hues.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';

class IconTile extends StatelessWidget {
  const IconTile(this.icon, {this.hue = SubjectHue.blue, super.key});

  final IconData icon;
  final SubjectHue hue;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return SizedBox.square(
      dimension: AppSize.iconTile,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: hue.wash(brightness),
          borderRadius: const BorderRadius.all(
            Radius.circular(AppRadius.control),
          ),
        ),
        child: Center(
          child: Icon(
            icon,
            size: AppSize.iconSmall,
            color: hue.color(brightness),
          ),
        ),
      ),
    );
  }
}
