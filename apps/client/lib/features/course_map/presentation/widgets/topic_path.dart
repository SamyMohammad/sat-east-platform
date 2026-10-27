import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_tokens.dart';

/// Horizontal centre of the topic tile inside a row.
const double topicPathX = AppSpace.s3 + AppSize.iconTile / 2;

/// Draws the path that runs through the tile centres of consecutive rows.
///
/// Each row paints the half of the path above its tile (when [upper] is not
/// null) and below it (when [lower] is not null). The halves of two
/// neighbouring rows meet at the row boundary, so the line reads as one path.
class TopicPathPainter extends CustomPainter {
  const TopicPathPainter({this.upper, this.lower});

  final TopicPathSegment? upper;
  final TopicPathSegment? lower;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.height / 2;
    const reach = AppSize.iconTile / 2;
    if (upper case final segment?) {
      _line(canvas, segment, 0, centre - reach);
    }
    if (lower case final segment?) {
      _line(canvas, segment, centre + reach, size.height);
    }
  }

  void _line(Canvas canvas, TopicPathSegment segment, double from, double to) {
    if (to <= from) return;
    final paint = Paint()
      ..color = segment.color
      ..strokeWidth = AppStroke.strong
      ..strokeCap = StrokeCap.round;
    if (segment.solid) {
      canvas.drawLine(Offset(topicPathX, from), Offset(topicPathX, to), paint);
      return;
    }
    for (var y = from; y < to; y += AppStroke.dash + AppStroke.dashGap) {
      canvas.drawLine(
        Offset(topicPathX, y),
        Offset(topicPathX, (y + AppStroke.dash).clamp(from, to)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(TopicPathPainter oldDelegate) =>
      upper != oldDelegate.upper || lower != oldDelegate.lower;
}

@immutable
class TopicPathSegment {
  const TopicPathSegment({required this.solid, required this.color});

  final bool solid;
  final Color color;

  @override
  bool operator ==(Object other) =>
      other is TopicPathSegment && other.solid == solid && other.color == color;

  @override
  int get hashCode => Object.hash(solid, color);
}
