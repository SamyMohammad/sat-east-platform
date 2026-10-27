import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart'
    deferred as pdf
    show PdfDocument, pdfrxFlutterInitialize;
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/notes/domain/services/pdf_page_counter.dart';

class PdfrxPageCounter implements PdfPageCounter {
  @override
  Future<Result<int>> count(Uint8List bytes) async {
    try {
      await pdf.loadLibrary();
      await pdf.pdfrxFlutterInitialize();
      final document = await pdf.PdfDocument.openData(bytes);
      try {
        final pages = document.pages.length;
        return pages > 0
            ? Success(pages)
            : const Failure(AppError(ErrorCodes.notesInvalidPdf));
      } finally {
        await document.dispose();
      }
    } on Object {
      return const Failure(AppError(ErrorCodes.notesInvalidPdf));
    }
  }
}
