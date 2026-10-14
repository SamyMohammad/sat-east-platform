import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/framed_panel.dart';

class HintPanel extends StatelessWidget {
  const HintPanel({required this.md, super.key});

  final String md;

  @override
  Widget build(BuildContext context) => FramedPanel(
    icon: Icons.lightbulb_outline_rounded,
    title: 'HINT',
    md: md,
    padding: BookletSpace.s4,
    titleColor: Theme.of(context).colorScheme.primary,
  );
}
