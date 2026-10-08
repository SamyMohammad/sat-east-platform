import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// Semi-transparent identity text that jumps to a new spot every [interval]
/// (ADR-002, SEC-01). Put it above the video in a Stack; it ignores touches.
class MovingWatermark extends StatefulWidget {
  const MovingWatermark({
    required this.text,
    this.interval = const Duration(seconds: 5),
    this.random,
    super.key,
  });

  final String text;
  final Duration interval;

  /// Injected in tests for deterministic positions.
  final Random? random;

  @override
  State<MovingWatermark> createState() => _MovingWatermarkState();
}

class _MovingWatermarkState extends State<MovingWatermark> {
  late final Random _random = widget.random ?? Random();
  late Timer _timer;
  Alignment _alignment = const Alignment(-0.6, -0.6);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.interval, (_) => _move());
  }

  void _move() {
    setState(() {
      // Stay inside ±0.85 so the text is never clipped at the edges.
      _alignment = Alignment(
        _random.nextDouble() * 1.7 - 0.85,
        _random.nextDouble() * 1.7 - 0.85,
      );
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedAlign(
        alignment: _alignment,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        child: Text(
          widget.text,
          key: const Key('watermark-text'),
          style: const TextStyle(
            color: Color(0x59FFFFFF), // ~35 % white
            fontSize: 16,
            fontWeight: FontWeight.w600,
            shadows: [Shadow(color: Color(0x59000000), blurRadius: 2)],
          ),
        ),
      ),
    );
  }
}
