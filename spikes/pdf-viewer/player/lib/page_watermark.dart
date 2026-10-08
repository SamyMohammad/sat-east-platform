import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Identity watermark drawn over one PDF page (SEC-02). It sits in the page's
/// own coordinates, so it scales and scrolls with the page at every zoom, and
/// it ignores pointer events. The text may be Arabic: Flutter shapes it.
class PageWatermark extends StatelessWidget {
  const PageWatermark({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) {
          // Font follows the rendered page width, so zooming keeps the layout.
          final fontSize = box.maxWidth / 22;
          final style = TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: const Color(0x40808080), // ~25 % grey
          );
          return ClipRect(
            child: Stack(
              children: [
                for (var row = 0; row < 4; row++)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: box.maxHeight * (0.1 + row * 0.24),
                    child: Transform.rotate(
                      angle: -math.pi / 7,
                      child: Text(
                        text,
                        key: Key('page-watermark-$row'),
                        textAlign: TextAlign.center,
                        style: style,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
