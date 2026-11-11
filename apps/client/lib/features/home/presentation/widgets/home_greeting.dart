import 'package:flutter/material.dart';
import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/home/presentation/home_copy.dart';

class HomeGreeting extends StatelessWidget {
  const HomeGreeting({
    required this.firstName,
    super.key,
    this.firstRun = false,
    this.courseTitle = '',
    this.unitTitle = '',
  });
  final String firstName;
  final bool firstRun;
  final String courseTitle;
  final String unitTitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: AppSpace.s1,
    children: [
      Text(
        HomeCopy.greeting(firstName, firstRun: firstRun),
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      if (courseTitle.isNotEmpty)
        Text(
          HomeCopy.subtitle(courseTitle, unitTitle),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.appColors.inkSecondary,
          ),
        ),
    ],
  );
}
