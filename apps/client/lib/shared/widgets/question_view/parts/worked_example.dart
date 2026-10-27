import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/framed_panel.dart';

class WorkedExample extends StatelessWidget {
  const WorkedExample({required this.label, required this.md, super.key});

  final String label;
  final String md;

  @override
  Widget build(BuildContext context) => FramedPanel(
    icon: AppIcons.workedExample,
    title: 'Worked example · $label',
    md: md,
    padding: AppSpace.s4 + AppSpace.s1,
    titleColor: Theme.of(context).colorScheme.onSurfaceVariant,
  );
}
