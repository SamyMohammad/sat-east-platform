part of 'app_progress.dart';

class _ProgressSegments extends CustomClipper<Path> {
  const _ProgressSegments();

  @override
  Path getClip(Size size) {
    // Keep the public fractional API; use ten equal visual steps.
    const count = 10;
    final gap = size.width < AppSize.progressSegmentGap * count
        ? 0.0
        : AppSize.progressSegmentGap;
    final width = (size.width - gap * (count - 1)) / count;
    final path = Path();
    for (var i = 0; i < count; i++) {
      path.addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * (width + gap), 0, width, size.height),
          Radius.circular(size.height / 2),
        ),
      );
    }
    return path;
  }

  @override
  bool shouldReclip(_ProgressSegments oldClipper) => false;
}
