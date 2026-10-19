import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';

class TeacherShell extends StatelessWidget {
  const TeacherShell({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
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
              Expanded(child: child ?? const _BuilderPlaceholder()),
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
    return ListView(
      padding: const EdgeInsets.all(BookletSpace.s3),
      children: [
        Padding(
          padding: const EdgeInsets.all(BookletSpace.s3),
          child: Text('Teacher area', style: theme.textTheme.titleLarge),
        ),
        const SizedBox(height: BookletSpace.s6),
        ListTile(
          selected: true,
          selectedTileColor: theme.colorScheme.primaryContainer,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(BookletRadius.sm)),
          ),
          leading: const Icon(Icons.account_tree_outlined),
          title: const Text('Course builder'),
          onTap: () => _go(context, '/teacher'),
        ),
        const Tooltip(
          message: 'Coming soon',
          child: ListTile(
            enabled: false,
            leading: Icon(Icons.settings_outlined),
            title: Text('Settings'),
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.arrow_back),
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
