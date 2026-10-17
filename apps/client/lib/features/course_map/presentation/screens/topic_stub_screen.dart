import 'package:flutter/material.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';

/// Placeholder for the topic page until practice ships.
class TopicStubScreen extends StatelessWidget {
  const TopicStubScreen({super.key, this.title});

  final String? title;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BookletSpace.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title ?? 'Topic', style: text.headlineSmall),
            const SizedBox(height: BookletSpace.s2),
            Text('Practice is coming next.', style: text.bodyMedium),
          ],
        ),
      ),
    );
  }
}
