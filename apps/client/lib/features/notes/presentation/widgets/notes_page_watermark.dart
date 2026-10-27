import 'dart:math' as math;

import 'package:flutter/material.dart';

class NotesPageWatermark extends StatelessWidget {
  const NotesPageWatermark({required this.text, super.key});
  final String text;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: LayoutBuilder(
      builder: (context, bounds) => ClipRect(
        child: Stack(
          children: [
            for (var row = 0; row < 4; row++)
              for (var column = 0; column < 2; column++)
                Positioned(
                  top: bounds.maxHeight * (0.12 + row * 0.24),
                  left: bounds.maxWidth * (column * 0.6 - 0.2),
                  width: bounds.maxWidth * 0.8,
                  child: Transform.rotate(
                    angle: -math.pi / 6,
                    child: Text(
                      text,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.ltr,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: bounds.maxWidth / 32,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF808080).withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    ),
  );
}
