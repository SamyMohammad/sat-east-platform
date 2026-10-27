import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_hues.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/shared/widgets/icon_tile.dart';

class TopicStepRow extends StatelessWidget {
  const TopicStepRow({
    required this.icon,
    required this.hue,
    required this.children,
    super.key,
  });

  final IconData icon;
  final SubjectHue hue;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpace.s3,
        children: [
          IconTile(icon, hue: hue),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpace.s3,
              children: children,
            ),
          ),
        ],
      ),
    ),
  );
}
