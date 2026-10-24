import 'dart:typed_data';

import 'package:sat_east_client/core/errors/result.dart';

abstract interface class NotesRepository {
  Future<Result<Uint8List>> download(String path);
  Future<Result<void>> markOpened(String assetId);
}
