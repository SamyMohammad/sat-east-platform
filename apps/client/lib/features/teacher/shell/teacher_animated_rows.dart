import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_motion.dart';

class TeacherAnimatedRows extends StatefulWidget {
  const TeacherAnimatedRows({
    required this.children,
    this.layoutBuilder,
    this.emptyState,
    super.key,
  });
  final List<Widget> children;
  final Widget Function(BuildContext, List<Widget>)? layoutBuilder;
  final Widget? emptyState;

  @override
  State<TeacherAnimatedRows> createState() => _TeacherAnimatedRowsState();
}

class _TeacherAnimatedRowsState extends State<TeacherAnimatedRows> {
  late List<Widget> _rows;
  final _entering = <Key>{};

  @override
  void initState() {
    super.initState();
    _rows = List.of(widget.children);
  }

  @override
  void didUpdateWidget(TeacherAnimatedRows oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousKeys = _rows.map((row) => row.key).toSet();
    final nextKeys = widget.children.map((row) => row.key).toSet();
    final next = List.of(widget.children);
    for (final row in next) {
      if (!previousKeys.contains(row.key)) _entering.add(row.key!);
    }
    if (!AppMotion.reduced(context)) {
      for (var index = 0; index < _rows.length; index++) {
        final row = _rows[index];
        if (!nextKeys.contains(row.key)) {
          next.insert(index.clamp(0, next.length), row);
        }
      }
    }
    _rows = next;
  }

  void _finished(Key key, bool removing) {
    _entering.remove(key);
    if (removing && mounted && !widget.children.any((row) => row.key == key)) {
      setState(() => _rows.removeWhere((row) => row.key == key));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_rows.isEmpty && widget.emptyState != null) return widget.emptyState!;
    final keys = widget.children.map((row) => row.key).toSet();
    final rows = [
      for (final row in _rows)
        TweenAnimationBuilder<double>(
          key: row.key,
          tween: Tween(
            begin: _entering.contains(row.key) ? 0 : 1,
            end: keys.contains(row.key) ? 1 : 0,
          ),
          duration: AppMotion.resolve(context, AppMotion.state),
          curve: AppMotion.standard,
          onEnd: () => _finished(row.key!, !keys.contains(row.key)),
          builder: (context, value, child) => ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: value,
              child: Opacity(opacity: value, child: child),
            ),
          ),
          child: IgnorePointer(
            ignoring: !keys.contains(row.key),
            child: ExcludeSemantics(
              excluding: !keys.contains(row.key),
              child: row,
            ),
          ),
        ),
    ];
    return widget.layoutBuilder?.call(context, rows) ??
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}
