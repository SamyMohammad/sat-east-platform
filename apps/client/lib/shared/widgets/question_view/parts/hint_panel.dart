import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_motion.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/framed_panel.dart';

class HintPanel extends StatelessWidget {
  const HintPanel({required this.md, super.key});

  final String md;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: AppMotion.resolve(context, AppMotion.enter),
    curve: AppMotion.emphasized,
    builder: (context, value, child) => ClipRect(
      child: Align(
        heightFactor: value,
        alignment: Alignment.topCenter,
        child: Opacity(opacity: value, child: child),
      ),
    ),
    child: FramedPanel(
      icon: AppIcons.hint,
      warm: true,
      title: 'Hint',
      md: md,
      padding: AppSpace.s4,
      titleColor: context.appColors.warmInk,
    ),
  );
}
