import 'dart:typed_data';

import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/notes/data/datasources/notes_remote_data_source.dart';
import 'package:sat_east_client/features/notes/domain/repositories/notes_repository.dart';

class NotesRepositoryImpl implements NotesRepository {
  NotesRepositoryImpl(this._remote);
  final NotesRemoteDataSource _remote;
  @override
  Future<Result<Uint8List>> download(String path) => _remote.download(path);
  @override
  Future<Result<void>> markOpened(String assetId) =>
      _remote.markOpened(assetId);
}
