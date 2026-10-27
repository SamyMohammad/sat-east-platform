import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_motion.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';

/// Local feedback motion only; correctness is supplied by the server result.
class ChoiceFeedbackMotion extends StatefulWidget {
  const ChoiceFeedbackMotion({
    required this.correct,
    required this.wrong,
    required this.outline,
    required this.color,
    required this.child,
    super.key,
  });

  final bool correct;
  final bool wrong;
  final bool outline;
  final Color color;
  final Widget child;

  @override
  State<ChoiceFeedbackMotion> createState() => _ChoiceFeedbackMotionState();
}

class _ChoiceFeedbackMotionState extends State<ChoiceFeedbackMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, value: 1);
  }

  @override
  void didUpdateWidget(ChoiceFeedbackMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.correct && !oldWidget.correct) ||
        (widget.wrong && !oldWidget.wrong) ||
        (widget.outline && !oldWidget.outline)) {
      _controller.duration = AppMotion.resolve(
        context,
        widget.outline
            ? AppMotion.state + AppMotion.enter
            : widget.wrong
            ? AppMotion.state
            : AppMotion.enter,
      );
      if (AppMotion.reduced(context)) {
        _controller.value = 1;
      } else {
        unawaited(_controller.forward(from: 0));
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) _controller.value = 1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) {
      final t = _controller.value;
      final shake = widget.wrong
          ? math.sin(t * math.pi * 4) * 6 * (1 - t)
          : 0.0;
      final pulse = widget.correct ? 1 + math.sin(t * math.pi) * 0.02 : 1.0;
      return Transform.translate(
        offset: Offset(shake, 0),
        child: Transform.scale(
          scale: pulse,
          child: CustomPaint(
            foregroundPainter: widget.outline
                ? _Outline(
                    color: widget.color,
                    progress:
                        ((t *
                                        (AppMotion.state + AppMotion.enter)
                                            .inMilliseconds -
                                    AppMotion.state.inMilliseconds) /
                                AppMotion.enter.inMilliseconds)
                            .clamp(0, 1),
                  )
                : null,
            child: child,
          ),
        ),
      );
    },
  );
}

class _Outline extends CustomPainter {
  const _Outline({required this.color, required this.progress});
  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(AppStroke.thin),
          const Radius.circular(AppRadius.choice),
        ),
      );
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppStroke.strong,
    );
  }

  @override
  bool shouldRepaint(_Outline oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

/// Draws the check path while preserving the semantic AppIcons glyph child.
class CheckStroke extends StatelessWidget {
  const CheckStroke({required this.child, required this.color, super.key});
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: AppMotion.resolve(context, AppMotion.enter),
    curve: AppMotion.emphasized,
    child: Opacity(opacity: 0, child: child),
    builder: (context, value, child) => CustomPaint(
      foregroundPainter: _CheckPath(color: color, progress: value),
      child: child,
    ),
  );
}

class _CheckPath extends CustomPainter {
  const _CheckPath({required this.color, required this.progress});
  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.2, size.height * 0.52)
      ..lineTo(size.width * 0.4, size.height * 0.72)
      ..lineTo(size.width * 0.8, size.height * 0.28);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppStroke.strong
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPath oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
