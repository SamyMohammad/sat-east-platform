import 'dart:typed_data';

import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/picked_file.dart';

// Web/stub implementations and deterministic test fakes share this boundary.
abstract interface class FilePickerService {
  Future<Result<PickedFile>> pickJson();
  Future<Result<PickedPdf>> pickPdf();
}

class PickedPdf {
  const PickedPdf({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
  int get size => bytes.length;
}
