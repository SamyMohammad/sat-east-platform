import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_motion.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';

const List<(String, IconData, String)> teacherDestinations = [
  ('Course builder', AppIcons.courseBuilder, '/teacher'),
  ('Settings', AppIcons.settings, '/teacher/settings'),
  ('Questions', AppIcons.quiz, '/teacher/questions'),
  ('Review', AppIcons.reviewQueue, '/teacher/review'),
];

int teacherDestinationIndex(String path) {
  if (path.startsWith('/teacher/settings')) return 1;
  if (path.startsWith('/teacher/questions')) return 2;
  if (path.startsWith('/teacher/review')) return 3;
  return 0;
}

class TeacherBottomNavigation extends StatelessWidget {
  const TeacherBottomNavigation({
    required this.path,
    required this.onSelected,
    required this.reviewBadge,
    super.key,
  });

  final String path;
  final ValueChanged<String> onSelected;
  final Widget reviewBadge;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final selected = teacherDestinationIndex(path);
    return Material(
      color: colors.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.line)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s1),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < teacherDestinations.length; i++)
                    Expanded(
                      child: _TeacherNavItem(
                        label: teacherDestinations[i].$1,
                        icon: teacherDestinations[i].$2,
                        selected: i == selected,
                        badge: teacherDestinations[i].$3 == '/teacher/review'
                            ? reviewBadge
                            : null,
                        onTap: () => onSelected(teacherDestinations[i].$3),
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
}

class _TeacherNavItem extends StatelessWidget {
  const _TeacherNavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final color = selected ? colors.brand : colors.inkSecondary;
    final glyph = Icon(icon, color: color);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.control),
          onTap: onTap,
          child: AnimatedContainer(
            duration: AppMotion.resolve(context, AppMotion.state),
            constraints: const BoxConstraints(minHeight: AppSize.touchTarget),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s1,
              vertical: AppSpace.s2,
            ),
            decoration: BoxDecoration(
              color: selected ? colors.raised : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(
                color: selected ? colors.line : Colors.transparent,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    glyph,
                    if (badge != null)
                      Positioned(
                        top: -AppSpace.s2,
                        right: -AppSpace.s3,
                        child: badge!,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpace.s1),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
