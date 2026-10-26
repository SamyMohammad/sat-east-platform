import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:sat_east_client/core/text/text_direction.dart';
import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_motion.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';

enum AppChipKind { difficulty, skill, filter }

class AppChip extends StatelessWidget {
  const AppChip({
    required this.label,
    super.key,
    this.kind = AppChipKind.skill,
    this.selected = false,
    this.onSelected,
    this.icon,
  });

  final String label;
  final AppChipKind kind;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.appColors;
    final motion = AnimationStyle(
      duration: AppMotion.resolve(context, AppMotion.state),
      reverseDuration: AppMotion.resolve(context, AppMotion.state),
      curve: AppMotion.standard,
      reverseCurve: AppMotion.standard,
    );
    final chipMotion = ChipAnimationStyle(
      enableAnimation: motion,
      selectAnimation: motion,
      avatarDrawerAnimation: motion,
      deleteDrawerAnimation: motion,
    );
    final filter = kind == AppChipKind.filter;
    final enabled = !filter || onSelected != null;
    final foreground = !enabled
        ? context.appColors.inkTertiary
        : filter && selected
        ? scheme.brand
        : scheme.ink;
    final border = BorderSide(
      color: !enabled
          ? scheme.line
          : filter && selected
          ? scheme.brand
          : filter
          ? scheme.lineStrong
          : scheme.line,
    );
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
    );
    final avatar = icon == null
        ? null
        : Icon(icon, size: AppSize.iconSmall, color: foreground);
    return LayoutBuilder(
      builder: (context, constraints) {
        final reserved =
            AppSpace.s3 * 2 + (icon != null || filter ? AppSize.iconSmall : 0);
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
          constraints: const BoxConstraints(minHeight: AppSize.touchTarget),
          child: filter
              ? FilterChip(
                  chipAnimationStyle: chipMotion,
                  label: text,
                  labelStyle: labelStyle,
                  avatar: avatar,
                  avatarBoxConstraints: const BoxConstraints.tightFor(
                    width: AppSize.iconSmall,
                    height: AppSize.iconSmall,
                  ),
                  selected: selected,
                  onSelected: onSelected,
                  side: border,
                  shape: shape,
                  padding: EdgeInsets.zero,
                  labelPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s3,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  visualDensity: VisualDensity.standard,
                  backgroundColor: scheme.surface,
                  selectedColor: scheme.brandWash,
                  disabledColor: scheme.surface,
                  checkmarkColor: foreground,
                )
              : Chip(
                  chipAnimationStyle: chipMotion,
                  label: text,
                  labelStyle: labelStyle,
                  avatar: avatar,
                  avatarBoxConstraints: const BoxConstraints.tightFor(
                    width: AppSize.iconSmall,
                    height: AppSize.iconSmall,
                  ),
                  side: border,
                  shape: shape,
                  padding: EdgeInsets.zero,
                  labelPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s3,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  visualDensity: VisualDensity.standard,
                  backgroundColor: scheme.surface,
                ),
        );
      },
    );
  }
}
