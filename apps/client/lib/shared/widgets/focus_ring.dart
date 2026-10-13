import 'package:flutter/material.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';

/// Keyboard focus outline: 2 px primary, 2 px outside the child (Foundations
/// focus rule). Paints outside its box; keep space.s1 free around it.
class FocusRing extends StatelessWidget {
  const FocusRing({
    required this.visible,
    required this.borderRadius,
    required this.child,
    super.key,
  });

  final bool visible;
  final double borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: visible
          ? FocusRingPainter(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: borderRadius,
            )
          : null,
      child: child,
    );
  }
}

class FocusRingPainter extends CustomPainter {
  const FocusRingPainter({required this.color, required this.borderRadius});

  final Color color;
  final double borderRadius;

  static const double _outset =
      BookletStroke.focusGap + BookletStroke.focusRing / 2;

  /// Centre line of the ring stroke for a child of [size].
  static Rect ringRect(Size size) => (Offset.zero & size).inflate(_outset);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        ringRect(size),
        Radius.circular(borderRadius + _outset),
      ),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = BookletStroke.focusRing,
    );
  }

  @override
  bool shouldRepaint(FocusRingPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.borderRadius != borderRadius;
}
