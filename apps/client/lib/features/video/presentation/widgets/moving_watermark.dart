import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sat_east_client/core/text/text_direction.dart';
import 'package:sat_east_client/core/theme/booklet_colors.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';

class MovingWatermark extends StatefulWidget {
  const MovingWatermark({
    required this.text,
    required this.period,
    required this.random,
    super.key,
  });

  final String text;
  final Duration period;
  final Random random;

  @override
  State<MovingWatermark> createState() => _MovingWatermarkState();
}

class _MovingWatermarkState extends State<MovingWatermark> {
  Timer? _timer;
  double _x = 0.1;
  double _y = 0.1;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.period, (_) {
      if (!mounted) return;
      setState(() {
        _x = widget.random.nextDouble();
        _y = widget.random.nextDouble();
      });
    });
  }

  @override
  void didUpdateWidget(MovingWatermark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, bounds) {
          final width = bounds.maxWidth * 0.7;
          final height = min(bounds.maxHeight, BookletSize.largeControl);
          return ClipRect(
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: BookletMotion.resolve(
                    context,
                    const Duration(milliseconds: 1500),
                  ),
                  curve: BookletMotion.standard,
                  left: (bounds.maxWidth - width) * _x,
                  top: (bounds.maxHeight - height) * _y,
                  width: width,
                  height: height,
                  child: Align(
                    child: Text(
                      widget.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textDirection: detectTextDirection(widget.text),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge!.copyWith(
                        color: BookletSchemes.light.surface.withValues(
                          alpha: 0.55,
                        ),
                        shadows: [
                          Shadow(
                            color: BookletSchemes.dark.shadow,
                            blurRadius: BookletSpace.s1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
