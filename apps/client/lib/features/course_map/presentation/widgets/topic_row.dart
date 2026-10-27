import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_hues.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/course_map/domain/entities/course_map.dart';
import 'package:sat_east_client/features/course_map/presentation/course_map_copy.dart';
import 'package:sat_east_client/features/course_map/presentation/widgets/topic_path.dart';
import 'package:sat_east_client/features/course_map/presentation/widgets/topic_unlock.dart';
import 'package:sat_east_client/shared/widgets/app_chip.dart';
import 'package:sat_east_client/shared/widgets/topic_number_tile.dart';

class TopicRow extends StatelessWidget {
  const TopicRow({
    required this.topic,
    super.key,
    this.hue = SubjectHue.blue,
    this.justUnlocked = false,
    this.connectFromPrevious = false,
    this.hasPrevious = false,
    this.hasNext = false,
    this.nextLocked = false,
    this.onUnlockComplete,
  });

  final MapTopic topic;
  final SubjectHue hue;
  final bool justUnlocked;
  final bool connectFromPrevious;

  /// A topic sits above / below this one in the same unit; the row draws its
  /// half of the path to it.
  final bool hasPrevious;
  final bool hasNext;
  final bool nextLocked;
  final VoidCallback? onUnlockComplete;

  void _open(BuildContext context) =>
      context.go(AppRoutes.topic(topic.id), extra: topic.title);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.appColors;
    final status = topic.status;
    final locked = status == TopicStatus.locked;
    final open = status == TopicStatus.open;
    final titleColor = locked ? colors.inkSecondary : scheme.onSurface;
    final reason = topic.lockReason;
    final lockLine = locked && reason is PreviousQuiz
        ? CourseMapCopy.lockLine(reason.afterTitle)
        : null;

    final statusWord = switch (status) {
      TopicStatus.completed => CourseMapCopy.statusCompleted,
      TopicStatus.open => CourseMapCopy.statusOpen,
      TopicStatus.locked => CourseMapCopy.statusLocked,
    };
    final statusIcon = switch (status) {
      TopicStatus.completed => AppIcons.correct,
      TopicStatus.open => AppIcons.unselected,
      TopicStatus.locked => AppIcons.locked,
    };

    final lineColor = hue.color(theme.brightness);
    final dashColor = colors.inkTertiary;
    TopicPathSegment segment({required bool solid}) =>
        TopicPathSegment(solid: solid, color: solid ? lineColor : dashColor);
    final solidIn = connectFromPrevious && !locked;
    final body = Container(
      constraints: const BoxConstraints(minHeight: AppSize.touchTarget),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s3,
        vertical: AppSpace.s3,
      ),
      decoration: BoxDecoration(
        color: open ? colors.brandWash : null,
        borderRadius: open ? BorderRadius.circular(AppRadius.card) : null,
        border: open
            ? Border.all(color: colors.brand)
            : Border(bottom: BorderSide(color: colors.line)),
      ),
      child: Row(
        children: [
          Opacity(
            opacity: locked ? AppOpacity.eliminated : 1,
            child: TopicNumberTile(topic.sortLabel, hue: hue),
          ),
          const SizedBox(width: AppSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  topic.title,
                  style: theme.textTheme.bodyLarge?.copyWith(color: titleColor),
                  textDirection: TextDirection.ltr,
                ),
                Wrap(
                  spacing: AppSpace.s2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(
                      statusIcon,
                      size: AppSize.iconSmall,
                      color: status == TopicStatus.completed
                          ? colors.correct
                          : titleColor,
                    ),
                    Text(
                      statusWord,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: titleColor,
                      ),
                    ),
                    if (topic.isFreePreview)
                      const AppChip(label: CourseMapCopy.freeChip),
                  ],
                ),
                if (lockLine != null)
                  Text(
                    lockLine,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.inkSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (!locked)
            Icon(
              AppIcons.next,
              color: open ? scheme.primary : scheme.onSurfaceVariant,
            ),
        ],
      ),
    );

    final content = CustomPaint(
      foregroundPainter: TopicPathPainter(
        upper: hasPrevious && !solidIn ? segment(solid: false) : null,
        lower: hasNext
            ? segment(
                solid: status == TopicStatus.completed && !nextLocked,
              )
            : null,
      ),
      child: body,
    );

    // The row hides its children from semantics, so the label must carry
    // everything a sighted user sees: status, the lock reason and the chip.
    final label = [
      '${topic.sortLabel} ${topic.title}',
      statusWord,
      ?lockLine,
      if (topic.isFreePreview) CourseMapCopy.freeChip,
    ].join(', ');

    return TopicUnlock(
      active: justUnlocked,
      connectFromPrevious: solidIn,
      hue: hue,
      onComplete: onUnlockComplete,
      child: Semantics(
        container: true,
        label: label,
        button: !locked,
        enabled: !locked,
        excludeSemantics: true,
        onTap: locked ? null : () => _open(context),
        child: locked
            ? content
            : InkWell(onTap: () => _open(context), child: content),
      ),
    );
  }
}
