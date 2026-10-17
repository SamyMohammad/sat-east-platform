import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/text/text_direction.dart';
import 'package:sat_east_client/core/theme/booklet_colors.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/course_map/domain/entities/course_map.dart';
import 'package:sat_east_client/features/course_map/presentation/course_map_copy.dart';
import 'package:sat_east_client/shared/widgets/booklet_chip.dart';

class TopicRow extends StatelessWidget {
  const TopicRow({required this.topic, super.key});

  final MapTopic topic;

  void _open(BuildContext context) =>
      context.go(AppRoutes.topic(topic.id), extra: topic.title);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final booklet = context.booklet;
    final status = topic.status;
    final locked = status == TopicStatus.locked;
    final open = status == TopicStatus.open;
    final titleColor = locked ? booklet.inkDisabled : scheme.onSurface;
    final reason = topic.lockReason;
    final lockLine = locked && reason is PreviousQuiz
        ? CourseMapCopy.lockLine(reason.afterTitle)
        : null;

    final leading = switch (status) {
      TopicStatus.completed => Icon(
        Icons.check_circle,
        color: booklet.greenTick,
        size: BookletSize.iconSmall,
      ),
      TopicStatus.open => Icon(
        Icons.radio_button_unchecked,
        color: scheme.primary,
        size: BookletSize.iconSmall,
      ),
      TopicStatus.locked => Icon(
        Icons.lock_outline,
        color: booklet.inkDisabled,
        size: BookletSize.iconSmall,
      ),
    };

    final content = Container(
      constraints: const BoxConstraints(minHeight: BookletSize.touchTarget),
      padding: const EdgeInsets.symmetric(
        horizontal: BookletSpace.s3,
        vertical: BookletSpace.s2,
      ),
      decoration: BoxDecoration(
        color: open ? scheme.primaryContainer : null,
        border: Border(
          bottom: BorderSide(color: scheme.outlineVariant),
          left: open
              ? BorderSide(color: scheme.primary, width: BookletStroke.current)
              : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: BookletSpace.s3),
          Text(
            topic.sortLabel,
            style: theme.textTheme.labelLarge?.copyWith(color: titleColor),
          ),
          const SizedBox(width: BookletSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  topic.title,
                  style: theme.textTheme.bodyLarge?.copyWith(color: titleColor),
                  textDirection: detectTextDirection(topic.title),
                ),
                if (lockLine != null)
                  Text(
                    lockLine,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: booklet.inkDisabled,
                    ),
                  ),
              ],
            ),
          ),
          if (topic.isFreePreview) ...[
            const SizedBox(width: BookletSpace.s2),
            const BookletChip(label: CourseMapCopy.freeChip),
          ],
          if (!locked)
            Icon(
              Icons.chevron_right,
              color: open ? scheme.primary : scheme.onSurfaceVariant,
            ),
        ],
      ),
    );

    final statusWord = switch (status) {
      TopicStatus.completed => CourseMapCopy.statusCompleted,
      TopicStatus.open => CourseMapCopy.statusOpen,
      TopicStatus.locked => CourseMapCopy.statusLocked,
    };
    // The row hides its children from semantics, so the label must carry
    // everything a sighted user sees: status, the lock reason and the chip.
    final label = [
      '${topic.sortLabel} ${topic.title}',
      statusWord,
      ?lockLine,
      if (topic.isFreePreview) CourseMapCopy.freeChip,
    ].join(', ');

    return Semantics(
      container: true,
      label: label,
      button: !locked,
      enabled: !locked,
      excludeSemantics: true,
      onTap: locked ? null : () => _open(context),
      child: locked
          ? content
          : InkWell(onTap: () => _open(context), child: content),
    );
  }
}
