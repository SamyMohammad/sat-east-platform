import 'package:flutter/material.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';

/// Bare auth layout (no shell): a centred, scrollable column no wider than
/// [BookletSize.authCard]. An optional [footer] stays pinned below the
/// scrolling content so the primary actions are always reachable.
class AuthCard extends StatelessWidget {
  const AuthCard({required this.children, super.key, this.footer});

  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(BookletSpace.s4),
                child: _Constrained(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: BookletSpace.s5,
                    children: children,
                  ),
                ),
              ),
            ),
          ),
          if (footer case final pinned?)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                BookletSpace.s4,
                BookletSpace.s2,
                BookletSpace.s4,
                BookletSpace.s4,
              ),
              child: _Constrained(child: pinned),
            ),
        ],
      ),
    ),
  );
}

class _Constrained extends StatelessWidget {
  const _Constrained({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: BookletSize.authCard),
    child: child,
  );
}
