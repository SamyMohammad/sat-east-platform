import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:mocktail/mocktail.dart';
import 'package:pdfrx/pdfrx.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/notes/presentation/widgets/notes_document.dart';

class _Page extends Mock implements PdfPage {}

/// Replaces native PDF rasterization, retaining the production page chrome.
Widget studentNotesPreview(
  BuildContext context,
  Uint8List bytes,
  Widget Function() watermark,
) {
  final viewer =
      buildNotesDocument(context, bytes, watermark, sourceName: 't1/a1.pdf')
          as PdfViewer;
  final page = _Page();
  when(() => page.pageNumber).thenReturn(1);
  return ColoredBox(
    color: viewer.params.backgroundColor,
    child: ListView(
      padding: EdgeInsets.all(viewer.params.margin),
      children: [
        SizedBox(
          height: 640,
          child: LayoutBuilder(
            builder: (context, bounds) {
              final rect = Offset.zero & Size(bounds.maxWidth, 640);
              return CustomPaint(
                foregroundPainter: _PageFrame(viewer.params, page),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ColoredBox(color: AppColors.light.background),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpace.s8),
                      child: Text(
                        'Linear equations',
                        style: TextStyle(color: AppColors.light.ink),
                      ),
                    ),
                    ...viewer.params.pageOverlaysBuilder!(context, rect, page),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _PageFrame extends CustomPainter {
  const _PageFrame(this.params, this.page);
  final PdfViewerParams params;
  final PdfPage page;

  @override
  void paint(Canvas canvas, Size size) {
    for (final paintPage
        in params.pagePaintCallbacks ?? <PdfViewerPagePaintCallback>[]) {
      paintPage(canvas, Offset.zero & size, page);
    }
  }

  @override
  bool shouldRepaint(_PageFrame oldDelegate) => oldDelegate.params != params;
}
