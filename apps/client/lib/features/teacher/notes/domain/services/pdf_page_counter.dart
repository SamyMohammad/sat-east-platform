import 'dart:typed_data';

import 'package:sat_east_client/core/errors/result.dart';

// Separates native PDF parsing from deterministic workflow tests.
// ignore: one_member_abstracts
abstract interface class PdfPageCounter {
  Future<Result<int>> count(Uint8List bytes);
}
