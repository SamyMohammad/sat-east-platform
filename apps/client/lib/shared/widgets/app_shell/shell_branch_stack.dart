import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sat_east_client/core/theme/app_motion.dart';

/// Keeps branch navigators mounted while fading through destination changes.
class ShellBranchStack extends StatefulWidget {
  const ShellBranchStack({
    required this.currentIndex,
    required this.children,
    super.key,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  State<ShellBranchStack> createState() => _ShellBranchStackState();
}

class _ShellBranchStackState extends State<ShellBranchStack>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: AppMotion.enter,
    value: 1,
  );
  int? _previous;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) _controller.value = 1;
  }

  @override
  void didUpdateWidget(ShellBranchStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _previous = oldWidget.currentIndex;
      if (AppMotion.reduced(context)) {
        _controller.value = 1;
      } else {
        unawaited(_controller.forward(from: 0));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          Offstage(
            offstage:
                i != widget.currentIndex &&
                (i != _previous || _controller.value >= 0.3),
            child: TickerMode(
              enabled: i == widget.currentIndex,
              child: ExcludeFocus(
                excluding: i != widget.currentIndex,
                child: ExcludeSemantics(
                  excluding: i != widget.currentIndex,
                  child: IgnorePointer(
                    ignoring: i != widget.currentIndex,
                    child: FadeTransition(
                      opacity: AlwaysStoppedAnimation(
                        i == widget.currentIndex
                            ? const Interval(
                                0.3,
                                1,
                                curve: AppMotion.emphasized,
                              ).transform(_controller.value)
                            : 1 -
                                  const Interval(
                                    0,
                                    0.3,
                                    curve: AppMotion.standard,
                                  ).transform(_controller.value),
                      ),
                      child: widget.children[i],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
