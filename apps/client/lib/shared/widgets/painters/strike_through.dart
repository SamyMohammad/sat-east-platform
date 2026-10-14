import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';

/// Draws a line through [child] when [struck], animated over motion.base
/// (reduced motion: motion.fast). Line overhangs the start by space.s1 and
/// stops space.s1 short of the end (Components.dc.html §2 eliminated).
class StrikeThrough extends StatefulWidget {
  const StrikeThrough({
    required this.struck,
    required this.color,
    required this.child,
    super.key,
  });

  final bool struck;
  final Color color;
  final Widget child;

  @override
  State<StrikeThrough> createState() => _StrikeThroughState();
}

class _StrikeThroughState extends State<StrikeThrough>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: widget.struck ? 1 : 0,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: BookletMotion.standard,
  );

  @override
  void didUpdateWidget(StrikeThrough oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.struck == widget.struck) return;
    _controller.duration = BookletMotion.resolve(context, BookletMotion.base);
    if (widget.struck) {
      unawaited(_controller.forward());
    } else {
      unawaited(_controller.reverse());
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: StrikeThroughPainter(
        progress: _curve,
        color: widget.color,
        textDirection: Directionality.of(context),
      ),
      child: widget.child,
    );
  }
}

class StrikeThroughPainter extends CustomPainter {
  StrikeThroughPainter({
    required this.progress,
    required this.color,
    required this.textDirection,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final Color color;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t == 0) return;
    final y = size.height / 2;
    final length = size.width * t;
    final paint = Paint()
      ..color = color
      ..strokeWidth = BookletStroke.strike;
    if (textDirection == TextDirection.ltr) {
      const start = -BookletSpace.s1;
      canvas.drawLine(Offset(start, y), Offset(start + length, y), paint);
    } else {
      final start = size.width + BookletSpace.s1;
      canvas.drawLine(Offset(start, y), Offset(start - length, y), paint);
    }
  }

  @override
  bool shouldRepaint(StrikeThroughPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.textDirection != textDirection ||
      oldDelegate.progress != progress;
}
