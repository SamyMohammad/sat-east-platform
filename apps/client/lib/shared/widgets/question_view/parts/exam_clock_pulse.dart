import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:sat_east_client/core/theme/app_motion.dart';

/// One pulse when warning becomes true, never on countdown ticks.
class ExamClockPulse extends StatefulWidget {
  const ExamClockPulse({required this.warning, required this.child, super.key});
  final bool warning;
  final Widget child;

  @override
  State<ExamClockPulse> createState() => _ExamClockPulseState();
}

class _ExamClockPulseState extends State<ExamClockPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, value: 1);
  }

  @override
  void didUpdateWidget(ExamClockPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.warning && !oldWidget.warning) {
      _pulse.duration = AppMotion.resolve(context, AppMotion.signature);
      if (AppMotion.reduced(context)) {
        _pulse.value = 1;
      } else {
        unawaited(_pulse.forward(from: 0));
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) _pulse.value = 1;
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _pulse,
    child: widget.child,
    builder: (context, child) => Transform.scale(
      scale: 1 + math.sin(_pulse.value * math.pi) * 0.02,
      child: child,
    ),
  );
}
