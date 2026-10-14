import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/framed_panel.dart';

class WorkedExample extends StatelessWidget {
  const WorkedExample({required this.label, required this.md, super.key});

  final String label;
  final String md;

  @override
  Widget build(BuildContext context) => FramedPanel(
    title: 'WORKED EXAMPLE · ${label.toUpperCase()}',
    md: md,
    padding: BookletSpace.s4 + BookletSpace.s1,
    titleColor: Theme.of(context).colorScheme.onSurfaceVariant,
  );
}
