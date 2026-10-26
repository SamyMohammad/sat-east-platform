import 'dart:async';

import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_hues.dart';
import 'package:sat_east_client/core/theme/app_motion.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';

/// Only decorates the server-provided open state; never gates interaction.
class TopicUnlock extends StatefulWidget {
  const TopicUnlock({
    required this.active,
    required this.connectFromPrevious,
    required this.hue,
    required this.child,
    super.key,
    this.onComplete,
  });

  final bool active;
  final bool connectFromPrevious;
  final SubjectHue hue;
  final Widget child;
  final VoidCallback? onComplete;

  @override
  State<TopicUnlock> createState() => _TopicUnlockState();
}

class _TopicUnlockState extends State<TopicUnlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _running = false;
  bool _acknowledged = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: AppMotion.signature,
          value: 1,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && _running) {
            _running = false;
            _acknowledge();
          }
        });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant TopicUnlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _generation++;
      _running = false;
      _controller.stop();
      _acknowledged = !widget.active;
      if (widget.active) {
        _sync();
      } else {
        _controller.value = 1;
      }
    }
  }

  void _sync() {
    if (!widget.active || _acknowledged) return;
    if (AppMotion.reduced(context)) {
      _controller.value = 1;
      _acknowledge();
    } else if (!_running) {
      _running = true;
      unawaited(_controller.forward(from: 0));
    }
  }

  void _acknowledge() {
    if (_acknowledged) return;
    _acknowledged = true;
    final generation = _generation;
    final onComplete = widget.onComplete;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.active && generation == _generation) {
        onComplete?.call();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      final progress = AppMotion.emphasized.transform(_controller.value);
      return CustomPaint(
        painter: widget.connectFromPrevious
            ? _Connector(
                progress,
                widget.hue.color(Theme.of(context).brightness),
                Directionality.of(context),
              )
            : null,
        child: Padding(
          padding: EdgeInsets.only(
            top: widget.connectFromPrevious ? AppSpace.s6 : 0,
          ),
          child: Stack(
            children: [
              Opacity(
                opacity:
                    AppOpacity.eliminated +
                    (1 - AppOpacity.eliminated) * progress,
                child: child,
              ),
              if (widget.active && progress < 1)
                PositionedDirectional(
                  start: AppSpace.s3,
                  top: AppSpace.s2,
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: Opacity(
                        opacity: 1 - progress,
                        child: SizedBox.square(
                          dimension: AppSize.iconTile,
                          child: CustomPaint(
                            painter: _OpeningLock(
                              progress,
                              widget.hue.color(Theme.of(context).brightness),
                            ),
                            key: const ValueKey('unlock-lock'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
    child: widget.child,
  );
}

class _Connector extends CustomPainter {
  const _Connector(this.progress, this.color, this.direction);
  final double progress;
  final Color color;
  final TextDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    const start = AppSpace.s3 + AppSize.iconTile / 2;
    final x = direction == TextDirection.ltr ? start : size.width - start;
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, AppSpace.s6 * progress),
      Paint()
        ..color = color
        ..strokeWidth = AppStroke.strong
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_Connector oldDelegate) =>
      progress != oldDelegate.progress ||
      color != oldDelegate.color ||
      direction != oldDelegate.direction;
}

class _OpeningLock extends CustomPainter {
  const _OpeningLock(this.progress, this.color);
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = AppStroke.strong
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(12, 20, 16, 12),
        const Radius.circular(AppSpace.s1),
      ),
      paint,
    );
    final lift = AppSpace.s2 * progress;
    canvas.drawPath(
      Path()
        ..moveTo(14, 20 - lift)
        ..lineTo(14, 14 - lift)
        ..cubicTo(14, 6 - lift, 26, 6 - lift, 26, 14 - lift)
        ..lineTo(26, 20 - lift),
      paint,
    );
  }

  @override
  bool shouldRepaint(_OpeningLock oldDelegate) =>
      progress != oldDelegate.progress || color != oldDelegate.color;
}
