import 'package:flutter/material.dart';

class FocusModeScaffold extends StatelessWidget {
  const FocusModeScaffold({
    required this.child,
    super.key,
    this.appBar,
    this.bottomBar,
  });

  final Widget child;
  final PreferredSizeWidget? appBar;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: appBar,
    body: SafeArea(child: child),
    bottomNavigationBar: bottomBar == null
        ? null
        : SafeArea(top: false, child: bottomBar!),
  );
}
