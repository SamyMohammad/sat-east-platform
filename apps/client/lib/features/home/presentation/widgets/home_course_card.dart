import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/home/domain/entities/home_summary.dart';
import 'package:sat_east_client/features/home/presentation/home_copy.dart';
import 'package:sat_east_client/shared/widgets/app_progress.dart';
import 'package:sat_east_client/shared/widgets/icon_tile.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

class HomeCourseCard extends StatelessWidget {
  const HomeCourseCard({required this.summary, super.key});
  final HomeReady summary;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpace.s4,
        children: [
          Row(
            spacing: AppSpace.s3,
            children: [
              const IconTile(AppIcons.courses),
              Expanded(
                child: Text(
                  summary.courseTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          AppProgress(
            label: HomeCopy.progress(summary.passed, summary.total),
            value: summary.total == 0 ? 0 : summary.passed / summary.total,
          ),
          LoadingButton(
            label: HomeCopy.openContents,
            icon: AppIcons.forward,
            variant: AppButtonVariant.tertiary,
            onPressed: () => context.go(AppRoutes.courses),
          ),
        ],
      ),
    ),
  );
}
