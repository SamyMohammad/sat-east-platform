import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/router/route_refresh_listener.dart';
import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/teacher/review/presentation/cubit/review_counts_cubit.dart';
import 'package:sat_east_client/features/teacher/shell/teacher_bottom_navigation.dart';
import 'package:sat_east_client/shared/widgets/app_shell/shell_header.dart';

class TeacherShell extends StatefulWidget {
  const TeacherShell({super.key, this.child});

  final Widget? child;

  @override
  State<TeacherShell> createState() => _TeacherShellState();
}

class _TeacherShellState extends State<TeacherShell> {
  late final ReviewCountsCubit _counts;
  @override
  void initState() {
    super.initState();
    _counts = getIt<ReviewCountsCubit>();
    unawaited(_counts.refresh());
  }

  @override
  void dispose() {
    unawaited(_counts.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = _shell(context);
    return BlocProvider.value(
      value: _counts,
      child: GoRouter.maybeOf(context) == null
          ? body
          : RouteRefreshListener(
              location: GoRouterState.of(context).uri.path,
              refreshOnReselect: true,
              onRefresh: () => unawaited(_counts.refresh()),
              child: body,
            ),
    );
  }

  Widget _shell(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final expanded =
          AppLayout.forWidth(constraints.maxWidth) == AppLayout.expanded;
      return Scaffold(
        bottomNavigationBar: expanded
            ? null
            : TeacherBottomNavigation(
                path: GoRouter.maybeOf(context) == null
                    ? ''
                    : GoRouterState.of(context).uri.path,
                reviewBadge: const _ReviewBadge(),
                onSelected: (path) => context.go(path),
              ),
        appBar: expanded ? null : AppBar(title: const Text('Teacher area')),
        drawer: expanded
            ? null
            : const Drawer(child: SafeArea(child: _TeacherNavigation())),
        body: SafeArea(
          child: Row(
            children: [
              if (expanded) ...[
                const SizedBox(
                  width: AppSize.shellSidebar,
                  child: _TeacherNavigation(),
                ),
                const VerticalDivider(width: AppStroke.thin),
              ],
              Expanded(child: widget.child ?? const _BuilderPlaceholder()),
            ],
          ),
        ),
      );
    },
  );
}

class _TeacherNavigation extends StatelessWidget {
  const _TeacherNavigation();

  void _go(BuildContext context, String path) {
    Scaffold.maybeOf(context)?.closeDrawer();
    context.go(path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsSelected =
        GoRouter.maybeOf(context) != null &&
        GoRouterState.of(context).uri.path == '/teacher/settings';
    final reviewSelected =
        GoRouter.maybeOf(context) != null &&
        GoRouterState.of(context).uri.path == '/teacher/review';
    final questionsSelected =
        GoRouter.maybeOf(context) != null &&
        GoRouterState.of(context).uri.path.startsWith('/teacher/questions');
    return Material(
      color: context.appColors.surface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const ShellWordmark(),
          const Divider(),
          const SizedBox(height: AppSpace.s3),
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpace.s6,
              bottom: AppSpace.s2,
            ),
            child: Text(
              'Teacher area',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          _NavTile(
            selected:
                !settingsSelected && !questionsSelected && !reviewSelected,
            icon: AppIcons.courseBuilder,
            title: 'Course builder',
            onTap: () => _go(context, '/teacher'),
          ),
          _NavTile(
            selected: settingsSelected,
            icon: AppIcons.settings,
            title: 'Settings',
            onTap: () => _go(context, '/teacher/settings'),
          ),
          _NavTile(
            selected: questionsSelected,
            icon: AppIcons.quiz,
            title: 'Questions',
            onTap: () => _go(context, '/teacher/questions'),
          ),
          _NavTile(
            selected: reviewSelected,
            icon: AppIcons.reviewQueue,
            title: 'Review',
            trailing: const _ReviewBadge(),
            onTap: () => _go(context, '/teacher/review'),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpace.s2),
            child: Divider(),
          ),
          _NavTile(
            selected: false,
            icon: AppIcons.back,
            title: 'Back to app',
            onTap: () => _go(context, '/'),
          ),
        ],
      ),
    );
  }
}

/// A sidebar row styled like the student shell's destination pill.
class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3),
      child: ListTile(
        selected: selected,
        selectedTileColor: colors.raised,
        selectedColor: colors.brand,
        iconColor: theme.colorScheme.onSurfaceVariant,
        textColor: theme.colorScheme.onSurface,
        minTileHeight: AppSize.touchTarget,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
        horizontalTitleGap: AppSpace.s3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          side: selected ? BorderSide(color: colors.line) : BorderSide.none,
        ),
        titleTextStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
        leading: Icon(icon),
        title: Text(title),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}

class _BuilderPlaceholder extends StatelessWidget {
  const _BuilderPlaceholder();

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(AppSpace.s6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpace.s4,
      children: [
        Text(
          'Course builder',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const Text('Coming in the next step.'),
      ],
    ),
  );
}

class _ReviewBadge extends StatelessWidget {
  const _ReviewBadge();
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<ReviewCountsCubit, ReviewCountsState>(
        builder: (context, state) {
          if (state.error != null) {
            return IconButton(
              tooltip: 'Retry review count',
              onPressed: () =>
                  unawaited(context.read<ReviewCountsCubit>().refresh()),
              icon: const Icon(AppIcons.retry),
            );
          }
          if (state.counts case final counts?) {
            return counts.total == 0
                ? const SizedBox.shrink()
                : Badge.count(count: counts.total);
          }
          return const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        },
      );
}
