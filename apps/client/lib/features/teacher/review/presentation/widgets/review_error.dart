import 'package:flutter/material.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/teacher/review/presentation/review_copy.dart';

class ReviewError extends StatelessWidget {
  const ReviewError({required this.code, required this.onRetry, super.key});
  final String code;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: BookletSpace.s3,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(reviewErrorCopy(code)),
      TextButton(onPressed: onRetry, child: const Text('Retry')),
    ],
  );
}
