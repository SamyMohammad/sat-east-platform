import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/router/route_refresh_listener.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/teacher/review/presentation/cubit/review_counts_cubit.dart';

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
          BookletLayout.forWidth(constraints.maxWidth) ==
          BookletLayout.expanded;
      return Scaffold(
        appBar: expanded ? null : AppBar(title: const Text('Teacher area')),
        drawer: expanded
            ? null
            : const Drawer(child: SafeArea(child: _TeacherNavigation())),
        body: SafeArea(
          child: Row(
            children: [
              if (expanded) ...[
                const SizedBox(
                  width: BookletSize.shellSidebar,
                  child: _TeacherNavigation(),
                ),
                const VerticalDivider(width: BookletStroke.thin),
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
    return ListView(
      padding: const EdgeInsets.all(BookletSpace.s3),
      children: [
        Padding(
          padding: const EdgeInsets.all(BookletSpace.s3),
          child: Text('Teacher area', style: theme.textTheme.titleLarge),
        ),
        const SizedBox(height: BookletSpace.s6),
        ListTile(
          selected: !settingsSelected && !questionsSelected && !reviewSelected,
          selectedTileColor: theme.colorScheme.primaryContainer,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(BookletRadius.sm)),
          ),
          leading: const Icon(AppIcons.courseBuilder),
          title: const Text('Course builder'),
          onTap: () => _go(context, '/teacher'),
        ),
        ListTile(
          selected: settingsSelected,
          selectedTileColor: theme.colorScheme.primaryContainer,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(BookletRadius.sm)),
          ),
          leading: const Icon(AppIcons.settings),
          title: const Text('Settings'),
          onTap: () => _go(context, '/teacher/settings'),
        ),
        ListTile(
          selected: questionsSelected,
          selectedTileColor: theme.colorScheme.primaryContainer,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(BookletRadius.sm)),
          ),
          leading: const Icon(AppIcons.quiz),
          title: const Text('Questions'),
          onTap: () => _go(context, '/teacher/questions'),
        ),
        ListTile(
          selected: reviewSelected,
          selectedTileColor: theme.colorScheme.primaryContainer,
          leading: const Icon(AppIcons.reviewQueue),
          title: const Text('Review'),
          trailing: const _ReviewBadge(),
          onTap: () => _go(context, '/teacher/review'),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(AppIcons.back),
          title: const Text('Back to app'),
          onTap: () => _go(context, '/'),
        ),
      ],
    );
  }
}

class _BuilderPlaceholder extends StatelessWidget {
  const _BuilderPlaceholder();

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(BookletSpace.s6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: BookletSpace.s4,
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
