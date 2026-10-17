import 'package:flutter/material.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';

class QuizStatusContent extends StatelessWidget {
  const QuizStatusContent({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: BookletSize.readingColumn),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(BookletSpace.s4),
        child: child,
      ),
    ),
  );
}
