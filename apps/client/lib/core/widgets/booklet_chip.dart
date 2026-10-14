import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:sat_east_client/core/text/text_direction.dart';
import 'package:sat_east_client/core/theme/booklet_colors.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';

enum BookletChipKind { difficulty, skill, filter }

class BookletChip extends StatelessWidget {
  const BookletChip({
    required this.label,
    super.key,
    this.kind = BookletChipKind.skill,
    this.selected = false,
    this.onSelected,
    this.icon,
  });

  final String label;
  final BookletChipKind kind;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final filter = kind == BookletChipKind.filter;
    final enabled = !filter || onSelected != null;
    final foreground = !enabled
        ? context.booklet.inkDisabled
        : filter && selected
        ? scheme.primary
        : scheme.onSurface;
    final border = BorderSide(
      color: !enabled
          ? scheme.outlineVariant
          : filter && selected
          ? scheme.primary
          : filter
          ? scheme.outline
          : scheme.outlineVariant,
    );
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(BookletRadius.xs)),
    );
    final avatar = icon == null
        ? null
        : Icon(icon, size: BookletSize.iconSmall, color: foreground);
    return LayoutBuilder(
      builder: (context, constraints) {
        final reserved =
            BookletSpace.s3 * 2 +
            (icon != null || filter ? BookletSize.iconSmall : 0);
        final labelStyle =
            (theme.textTheme.labelLarge ?? DefaultTextStyle.of(context).style)
                .copyWith(color: foreground);
        final text = ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: math.max(0, constraints.maxWidth - reserved),
          ),
          child: DefaultTextStyle(
            // RawChip's inherited style otherwise forces one clipped line.
            style: labelStyle,
            child: Text(label, textDirection: detectTextDirection(label)),
          ),
        );
        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: BookletSize.touchTarget),
          child: filter
              ? FilterChip(
                  label: text,
                  labelStyle: labelStyle,
                  avatar: avatar,
                  avatarBoxConstraints: const BoxConstraints.tightFor(
                    width: BookletSize.iconSmall,
                    height: BookletSize.iconSmall,
                  ),
                  selected: selected,
                  onSelected: onSelected,
                  side: border,
                  shape: shape,
                  padding: EdgeInsets.zero,
                  labelPadding: const EdgeInsets.symmetric(
                    horizontal: BookletSpace.s3,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  visualDensity: VisualDensity.standard,
                  backgroundColor: scheme.surface,
                  selectedColor: scheme.primaryContainer,
                  disabledColor: scheme.surface,
                  checkmarkColor: foreground,
                )
              : Chip(
                  label: text,
                  labelStyle: labelStyle,
                  avatar: avatar,
                  avatarBoxConstraints: const BoxConstraints.tightFor(
                    width: BookletSize.iconSmall,
                    height: BookletSize.iconSmall,
                  ),
                  side: kind == BookletChipKind.skill
                      ? BorderSide.none
                      : border,
                  shape: shape,
                  padding: EdgeInsets.zero,
                  labelPadding: const EdgeInsets.symmetric(
                    horizontal: BookletSpace.s3,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  visualDensity: VisualDensity.standard,
                  backgroundColor: kind == BookletChipKind.skill
                      ? context.booklet.frameTint
                      : scheme.surface,
                ),
        );
      },
    );
  }
}
