import 'package:flutter/material.dart';

import 'package:sat_east_client/core/math_render/math_text.dart';
import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';

enum MarginNoteTone { miss, correct }

/// Teacher's margin note. [inline] puts the rule on top (phone/medium);
/// otherwise it sits on the leading edge (wide aside). Live region; the
/// icon + text carry the meaning so colour is never the only signal.
class MarginNote extends StatelessWidget {
  const MarginNote({
    required this.tone,
    required this.author,
    required this.bodyMd,
    super.key,
    this.inline = true,
    this.teacherLine = false,
  });

  final MarginNoteTone tone;
  final String? author;
  final String bodyMd;
  final bool inline;
  final bool teacherLine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final miss = tone == MarginNoteTone.miss;
    final color = teacherLine
        ? context.appColors.warmInk
        : miss
        ? scheme.error
        : context.appColors.correct;
    final headerText = teacherLine
        ? author
        : miss
        ? author
        : 'Correct';
    final rule = BorderSide(color: color);

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              miss ? AppIcons.workedExample : AppIcons.correct,
              size: AppSize.iconStatus,
              color: color,
            ),
            if (headerText != null) ...[
              const SizedBox(width: AppSpace.s2),
              Flexible(
                child: Text(
                  headerText,
                  style: theme.textTheme.labelSmall?.copyWith(color: color),
                ),
              ),
            ],
          ],
        ),
        if (bodyMd.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s2),
          MathText(
            bodyMd,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: teacherLine
                  ? context.appColors.ink
                  : miss
                  ? scheme.error
                  : scheme.onSurface,
              fontWeight: miss ? FontWeight.w500 : null,
            ),
          ),
        ],
      ],
    );

    return Semantics(
      liveRegion: !teacherLine,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: teacherLine ? context.appColors.warm : null,
          borderRadius: teacherLine
              ? BorderRadius.circular(AppRadius.control)
              : null,
          border: teacherLine
              ? Border.all(color: context.appColors.warmLine)
              : inline
              ? Border(top: rule)
              : BorderDirectional(start: rule),
        ),
        child: Padding(
          padding: teacherLine
              ? const EdgeInsets.all(AppSpace.s3)
              : inline
              ? const EdgeInsets.only(top: AppSpace.s3)
              : const EdgeInsetsDirectional.only(start: AppSpace.s6),
          child: body,
        ),
      ),
    );
  }
}
