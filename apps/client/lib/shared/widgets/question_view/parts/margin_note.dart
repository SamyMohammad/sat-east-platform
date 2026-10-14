import 'package:flutter/material.dart';

import 'package:sat_east_client/core/math_render/math_text.dart';
import 'package:sat_east_client/core/theme/booklet_colors.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';

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
  });

  final MarginNoteTone tone;
  final String? author;
  final String bodyMd;
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final miss = tone == MarginNoteTone.miss;
    final color = miss ? scheme.error : context.booklet.greenTick;
    final headerText = miss ? author : 'Correct';
    final rule = BorderSide(color: color);

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              miss ? Icons.draw_outlined : Icons.check_circle_rounded,
              size: BookletSize.iconStatus,
              color: color,
            ),
            if (headerText != null) ...[
              const SizedBox(width: BookletSpace.s2),
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
          const SizedBox(height: BookletSpace.s2),
          MathText(
            bodyMd,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: miss ? scheme.error : scheme.onSurface,
              fontWeight: miss ? FontWeight.w500 : null,
            ),
          ),
        ],
      ],
    );

    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: inline ? Border(top: rule) : BorderDirectional(start: rule),
        ),
        child: Padding(
          padding: inline
              ? const EdgeInsets.only(top: BookletSpace.s3)
              : const EdgeInsetsDirectional.only(start: BookletSpace.s6),
          child: body,
        ),
      ),
    );
  }
}
