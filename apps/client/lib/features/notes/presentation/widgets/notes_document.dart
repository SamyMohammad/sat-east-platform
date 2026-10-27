import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:pdfrx/pdfrx.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/core/theme/app_type.dart';
import 'package:sat_east_client/shared/widgets/app_skeleton.dart';

typedef NotesDocumentBuilder =
    Widget Function(
      BuildContext context,
      Uint8List bytes,
      Widget Function() pageOverlay,
    );
Widget buildNotesDocument(
  BuildContext context,
  Uint8List bytes,
  Widget Function() pageOverlay, {
  required String sourceName,
}) => PdfViewer.data(
  bytes,
  sourceName: sourceName,
  params: PdfViewerParams(
    margin: AppSpace.s4,
    backgroundColor: context.appColors.background,
    pageDropShadow: null,
    pagePaintCallbacks: [
      (canvas, rect, page) {
        final frame = RRect.fromRectAndRadius(
          rect,
          const Radius.circular(AppRadius.card),
        );
        final corners = Path.combine(
          PathOperation.difference,
          Path()..addRect(rect),
          Path()..addRRect(frame),
        );
        canvas
          ..drawPath(corners, Paint()..color = context.appColors.background)
          ..drawRRect(
            frame,
            Paint()
              ..color = context.appColors.line
              ..style = PaintingStyle.stroke
              ..strokeWidth = AppStroke.thin,
          );
      },
    ],
    loadingBannerBuilder: (context, downloaded, total) => const Padding(
      padding: EdgeInsets.all(AppSpace.s4),
      child: AppSkeleton(),
    ),
    textSelectionParams: const PdfTextSelectionParams(enabled: false),
    pageOverlaysBuilder: (context, pageRect, page) => [
      Positioned.fill(child: pageOverlay()),
      Positioned(
        right: AppSpace.s3,
        bottom: AppSpace.s3,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.appColors.surface,
              border: Border.all(color: context.appColors.line),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s3,
                vertical: AppSpace.s1,
              ),
              child: Text(
                '${page.pageNumber}',
                style: AppType.count.copyWith(color: context.appColors.ink),
              ),
            ),
          ),
        ),
      ),
    ],
    errorBannerBuilder: (context, error, stackTrace, ref) =>
        const Center(child: Text("Couldn't load this page.")),
  ),
);
