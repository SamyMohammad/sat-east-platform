import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:sat_east_client/features/notes/presentation/widgets/notes_document.dart';

void main() {
  testWidgets('SEC-02: memory viewer isolates assets and disables selection', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox));
    final viewer =
        buildNotesDocument(
              context,
              Uint8List.fromList([1]),
              () => const Text('Watermark'),
              sourceName: 't1/a1.pdf',
            )
            as PdfViewer;
    final other =
        buildNotesDocument(
              context,
              Uint8List.fromList([2]),
              () => const Text('Watermark'),
              sourceName: 't1/a2.pdf',
            )
            as PdfViewer;
    expect(viewer.documentRef.key.sourceName, 't1/a1.pdf');
    expect(viewer.documentRef.key, isNot(other.documentRef.key));
    expect(viewer.params.textSelectionParams?.enabled, isFalse);
    expect(viewer.params.pageOverlaysBuilder, isNotNull);
  });
}
