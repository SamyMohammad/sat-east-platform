import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_motion.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';

/// A thin horizontal bar whose fill grows once, staggered by [index]
/// (40 ms per step). Static under reduced motion. Purely visual: put the
/// value in text next to it.
class GrowingBar extends StatefulWidget {
  const GrowingBar({
    required this.value,
    required this.color,
    super.key,
    this.index = 0,
  });

  /// Fill fraction, clamped to 0..1.
  final double value;
  final Color color;

  /// Position in a list; delays the start by `index * AppMotion.stagger`.
  final int index;

  /// Rows beyond this share the last delay so long lists settle quickly.
  static const int maxStaggerSteps = 10;

  @override
  State<GrowingBar> createState() => _GrowingBarState();
}

class _GrowingBarState extends State<GrowingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fill;

  @override
  void initState() {
    super.initState();
    final delay =
        AppMotion.stagger * math.min(widget.index, GrowingBar.maxStaggerSteps);
    final total = delay + AppMotion.enter;
    _controller = AnimationController(vsync: this, duration: total);
    _fill = _controller.drive(
      CurveTween(
        curve: Interval(
          delay.inMicroseconds / total.inMicroseconds,
          1,
          curve: AppMotion.emphasized,
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final duration = AppMotion.resolve(context, _controller.duration!);
    if (duration == Duration.zero) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      unawaited(_controller.forward());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.value.isFinite ? widget.value.clamp(0.0, 1.0) : 0.0;
    return ExcludeSemantics(
      child: SizedBox(
        height: AppSpace.s2,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.appColors.line,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: AnimatedBuilder(
            animation: _fill,
            builder: (context, _) => FractionallySizedBox(
              key: const ValueKey('growing-bar-fill'),
              alignment: AlignmentDirectional.centerStart,
              widthFactor: target * _fill.value,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
