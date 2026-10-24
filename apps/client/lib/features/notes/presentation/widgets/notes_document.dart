import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

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
    textSelectionParams: const PdfTextSelectionParams(enabled: false),
    pageOverlaysBuilder: (context, pageRect, page) => [
      Positioned.fill(child: pageOverlay()),
    ],
    errorBannerBuilder: (context, error, stackTrace, ref) =>
        const Center(child: Text("Couldn't load this page.")),
  ),
);
