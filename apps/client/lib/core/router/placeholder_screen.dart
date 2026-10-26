import 'package:flutter/material.dart';
import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/shared/widgets/icon_tile.dart';

/// Temporary destination content until each feature lands.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, this.title});

  final String? title;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSize.readingColumn),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpace.s3,
              children: [
                IconTile(switch (title) {
                  'Skills' => AppIcons.skills,
                  'Mock exams' => AppIcons.mockExams,
                  _ => AppIcons.home,
                }),
                Text(
                  title ?? 'SAT East',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  'This page will be available soon.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.appColors.inkSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
