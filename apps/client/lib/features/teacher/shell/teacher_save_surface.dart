import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_motion.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';

class TeacherSaveSurface extends StatelessWidget {
  const TeacherSaveSurface({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 1, end: 0),
    duration: AppMotion.resolve(context, AppMotion.enter),
    curve: AppMotion.emphasized,
    builder: (context, value, child) =>
        FractionalTranslation(translation: Offset(0, value), child: child),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: context.appColors.surface,
        border: Border(top: BorderSide(color: context.appColors.line)),
        boxShadow: [
          BoxShadow(
            color: context.appColors.shadow,
            blurRadius: AppSpace.s4,
            offset: const Offset(0, -AppSpace.s1),
          ),
        ],
      ),
      child: child,
    ),
  );
}
