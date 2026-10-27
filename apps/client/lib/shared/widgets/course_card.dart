import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_hues.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/shared/widgets/icon_tile.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

/// One course card for every course list: hue cover band, [IconTile], title,
/// body and an optional action.
class CourseCard extends StatelessWidget {
  const CourseCard({
    required this.title,
    super.key,
    this.hue = SubjectHue.blue,
    this.coverKey,
    this.body,
    this.meta,
    this.price,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final SubjectHue hue;
  final Key? coverKey;
  final String? body;
  final String? meta;
  final String? price;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: AppSpace.s2,
            child: ColoredBox(
              key: coverKey,
              color: hue.color(theme.brightness),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpace.s6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpace.s4,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: IconTile(AppIcons.courses, hue: hue),
                ),
                Text(
                  title,
                  style: theme.textTheme.headlineSmall,
                  textDirection: TextDirection.ltr,
                ),
                if (body case final text?)
                  Text(text, textDirection: TextDirection.ltr),
                if (meta case final text?)
                  Text(text, style: theme.textTheme.bodySmall),
                if (price case final text?)
                  Text(text, style: theme.textTheme.titleLarge),
                if (actionLabel case final label?)
                  LoadingButton(label: label, onPressed: onAction),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
