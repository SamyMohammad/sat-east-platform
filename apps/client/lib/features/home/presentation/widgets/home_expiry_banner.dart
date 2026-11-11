import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/features/home/domain/entities/home_summary.dart';
import 'package:sat_east_client/features/home/presentation/home_copy.dart';
import 'package:sat_east_client/shared/widgets/app_banner.dart';

class HomeExpiryBanner extends StatelessWidget {
  const HomeExpiryBanner({
    required this.courseTitle,
    required this.warning,
    super.key,
  });
  final String courseTitle;
  final ExpiryWarning warning;

  @override
  Widget build(BuildContext context) => AppBanner(
    kind: AppBannerKind.warning,
    message: HomeCopy.expiry(
      courseTitle,
      warning.daysLeft,
      MaterialLocalizations.of(
        context,
      ).formatMediumDate(warning.expiresAt.toLocal()),
    ),
    actionLabel: HomeCopy.activate,
    onAction: () => context.go(AppRoutes.activate),
  );
}
