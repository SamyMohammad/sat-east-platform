import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Keeps the scroll clearance in sync with the pinned dock's rendered height.
class PracticeQuestionLayout extends StatefulWidget {
  const PracticeQuestionLayout({
    required this.body,
    required this.dock,
    super.key,
  });

  final Widget body;
  final Widget dock;

  static double bottomInsetOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_PracticeDockInset>()
          ?.height ??
      0;

  @override
  State<PracticeQuestionLayout> createState() => _PracticeQuestionLayoutState();
}

class _PracticeQuestionLayoutState extends State<PracticeQuestionLayout> {
  double _dockHeight = 0;

  void _resizeDock(double height) {
    if (!mounted || height == _dockHeight) return;
    setState(() => _dockHeight = height);
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      _PracticeDockInset(height: _dockHeight, child: widget.body),
      Align(
        alignment: Alignment.bottomCenter,
        child: _DockMeasure(onHeight: _resizeDock, child: widget.dock),
      ),
    ],
  );
}

class _PracticeDockInset extends InheritedWidget {
  const _PracticeDockInset({required this.height, required super.child});

  final double height;

  @override
  bool updateShouldNotify(_PracticeDockInset oldWidget) =>
      height != oldWidget.height;
}

class _DockMeasure extends SingleChildRenderObjectWidget {
  const _DockMeasure({required this.onHeight, required super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _DockMeasureBox(onHeight);

  @override
  void updateRenderObject(BuildContext context, _DockMeasureBox renderObject) {
    renderObject.onHeight = onHeight;
  }
}

class _DockMeasureBox extends RenderProxyBox {
  _DockMeasureBox(this.onHeight);

  ValueChanged<double> onHeight;
  double? _lastHeight;

  @override
  void performLayout() {
    super.performLayout();
    if (_lastHeight == size.height) return;
    final height = _lastHeight = size.height;
    WidgetsBinding.instance.addPostFrameCallback((_) => onHeight(height));
  }
}
