import 'dart:typed_data';

import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/auth/domain/repositories/auth_repository.dart';
import 'package:sat_east_client/features/notes/domain/repositories/notes_repository.dart';

class MockNotesAuth extends Mock implements AuthRepository {}

class FakeNotesRepository implements NotesRepository {
  Result<Uint8List> downloadResult = Success(Uint8List.fromList([1, 2, 3]));
  Result<void> markResult = const Success(null);
  Future<Result<Uint8List>>? pendingDownload;
  Future<Result<void>>? pendingMark;
  void Function()? onDownload;
  final List<String> downloads = [];
  final List<String> marks = [];
  @override
  Future<Result<Uint8List>> download(String path) {
    downloads.add(path);
    onDownload?.call();
    return pendingDownload ?? Future.value(downloadResult);
  }

  @override
  Future<Result<void>> markOpened(String assetId) {
    marks.add(assetId);
    return pendingMark ?? Future.value(markResult);
  }
}
