import 'package:flutter/material.dart';

import 'package:sat_east_client/features/teacher/review/presentation/review_copy.dart';
import 'package:sat_east_client/shared/widgets/app_banner.dart';

class ReviewError extends StatelessWidget {
  const ReviewError({required this.code, required this.onRetry, super.key});
  final String code;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => AppBanner(
    message: reviewErrorCopy(code),
    kind: AppBannerKind.error,
    actionLabel: 'Retry',
    onAction: onRetry,
  );
}
