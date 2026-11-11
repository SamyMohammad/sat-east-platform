import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/home/domain/entities/home_summary.dart';
import 'package:sat_east_client/features/home/presentation/home_copy.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

class HomeMessageCard extends StatelessWidget {
  const HomeMessageCard({required this.summary, super.key});
  final HomeSummary summary;

  @override
  Widget build(BuildContext context) {
    final (message, label, route, icon) = switch (summary) {
      HomeFinished(:final courseTitle) => (
        HomeCopy.finished(courseTitle),
        HomeCopy.openContents,
        AppRoutes.courses,
        AppIcons.completed,
      ),
      HomeExpired() => (
        HomeCopy.expired,
        HomeCopy.activate,
        AppRoutes.activate,
        AppIcons.locked,
      ),
      HomeNotEnrolled() => (
        HomeCopy.notEnrolled,
        HomeCopy.browseCourses,
        AppRoutes.catalogue,
        AppIcons.courses,
      ),
      HomeReady() => throw StateError('Ready summary requires a continue card'),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpace.s4,
          children: [
            Icon(icon, size: AppSize.statusIcon),
            Text(message, style: Theme.of(context).textTheme.titleLarge),
            LoadingButton(label: label, onPressed: () => context.go(route)),
          ],
        ),
      ),
    );
  }
}
