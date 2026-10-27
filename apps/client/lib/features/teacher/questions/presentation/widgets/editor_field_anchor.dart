import 'package:flutter/material.dart';

class EditorFieldTargets extends InheritedWidget {
  const EditorFieldTargets({
    required this.targets,
    required super.child,
    super.key,
  });
  final Map<String, GlobalKey> targets;

  static GlobalKey? targetOf(BuildContext context, String field) => context
      .dependOnInheritedWidgetOfExactType<EditorFieldTargets>()
      ?.targets[field];

  @override
  bool updateShouldNotify(EditorFieldTargets oldWidget) =>
      targets != oldWidget.targets;
}

class EditorFieldAnchor extends StatelessWidget {
  const EditorFieldAnchor({
    required this.field,
    required this.child,
    super.key,
  });
  final String field;
  final Widget child;

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: EditorFieldTargets.targetOf(context, field),
    child: child,
  );
}
