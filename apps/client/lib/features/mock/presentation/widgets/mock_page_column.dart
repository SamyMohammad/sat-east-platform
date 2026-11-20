import 'package:flutter/material.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';

/// Centred reading column shared by the mock hub and pre-exam pages.
class MockPageColumn extends StatelessWidget {
  const MockPageColumn({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppSize.readingColumn),
      child: ListView(
        padding: const EdgeInsets.all(AppSpace.s4),
        children: [
          for (final child in children) ...[
            child,
            const SizedBox(height: AppSpace.s4),
          ],
        ],
      ),
    ),
  );
}
