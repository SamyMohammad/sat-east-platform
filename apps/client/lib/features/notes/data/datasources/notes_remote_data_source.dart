import 'dart:typed_data';

import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/errors/supabase_error_mapper.dart';
import 'package:sat_east_client/core/supabase/rpc_caller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef NotesDownload = Future<Uint8List> Function(String path);

class NotesRemoteDataSource {
  NotesRemoteDataSource(this._download, this._rpc);
  final NotesDownload _download;
  final RpcCaller _rpc;
  Future<Result<Uint8List>> download(String path) => _call(() async {
    final bytes = await _download(path);
    if (bytes.isEmpty) throw const FormatException('empty notes');
    return bytes;
  });
  Future<Result<void>> markOpened(String assetId) => _call(() async {
    final result = await _rpc('mark_notes_opened', {'p_asset_id': assetId});
    if (result is! Map<String, Object?> ||
        result['notes_opened_at'] is! String ||
        DateTime.tryParse(result['notes_opened_at']! as String) == null) {
      throw const FormatException('notes timestamp');
    }
  });
  Future<Result<T>> _call<T>(Future<T> Function() action) async {
    try {
      return Success(await action());
    } on PostgrestException catch (e) {
      return Failure(mapPostgrestException(e));
    } on StorageException catch (e) {
      final code = ErrorCodes.isServerCode(e.message)
          ? e.message
          : switch (e.statusCode) {
              '401' => ErrorCodes.notAuthenticated,
              '403' => ErrorCodes.forbidden,
              '404' => ErrorCodes.invalidInput,
              _ => ErrorCodes.internal,
            };
      return Failure(AppError(code));
    } on FormatException {
      return const Failure(AppError(ErrorCodes.internal));
    } on Object catch (e) {
      return Failure(mapUnknownError(e));
    }
  }
}
