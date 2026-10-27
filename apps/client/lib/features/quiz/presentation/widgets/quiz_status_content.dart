import 'package:flutter/material.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';

class QuizStatusContent extends StatelessWidget {
  const QuizStatusContent({
    required this.child,
    this.maxWidth = AppSize.readingColumn,
    this.alignment = Alignment.topCenter,
    super.key,
  });

  final Widget child;
  final double maxWidth;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => Align(
    alignment: alignment,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: child,
      ),
    ),
  );
}
