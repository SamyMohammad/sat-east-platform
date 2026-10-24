import 'dart:typed_data';

import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/errors/supabase_error_mapper.dart';
import 'package:sat_east_client/core/supabase/rpc_caller.dart';
import 'package:sat_east_client/features/teacher/notes/domain/entities/teacher_note.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef ReadNotes = Future<Object?> Function(String topicId);
typedef ReadNotesLimit = Future<Object?> Function();
typedef UploadNotesBytes = Future<void> Function(String path, Uint8List bytes);
typedef RemoveNotesObject = Future<void> Function(String path);

class TeacherNotesRemoteDataSource {
  TeacherNotesRemoteDataSource({
    required this._rpc,
    required this._readNotes,
    required this._readLimit,
    required this._uploadBytes,
    required this._removeObject,
  });
  final RpcCaller _rpc;
  final ReadNotes _readNotes;
  final ReadNotesLimit _readLimit;
  final UploadNotesBytes _uploadBytes;
  final RemoveNotesObject _removeObject;

  Future<Result<List<TeacherNote>>> list(String topicId) => _call(() async {
    final raw = await _readNotes(topicId);
    if (raw is! List<Object?>) throw const FormatException('notes');
    return raw.map((item) {
      final row = _object(item);
      final pages = row['page_count'];
      final ready = row['ready'];
      final subtopic = row['subtopic_id'];
      if (pages is! int ||
          pages <= 0 ||
          ready is! bool ||
          (subtopic != null && subtopic is! String)) {
        throw const FormatException('note');
      }
      return TeacherNote(
        id: _text(row['id']),
        title: _text(row['title']),
        pageCount: pages,
        ready: ready,
        subtopicId: subtopic as String?,
      );
    }).toList();
  });
  Future<Result<int>> maxUploadMb() => _call(() async {
    final value = _object(await _readLimit())['value'];
    if (value is! int || value <= 0) throw const FormatException('notes limit');
    return value;
  });
  Future<Result<CreatedNote>> create(String topicId, String title, int pages) =>
      _call(() async {
        final row = _object(
          await _rpc('teacher_create_notes_asset', {
            'p_topic_id': topicId,
            'p_subtopic_id': null,
            'p_title': title,
            'p_page_count': pages,
          }),
        );
        final id = _text(row['asset_id']);
        final path = _text(row['path']);
        if (path != '$topicId/$id.pdf') {
          throw const FormatException('notes path');
        }
        return CreatedNote(id: id, path: path);
      });
  Future<Result<void>> upload(String path, Uint8List bytes) =>
      _call(() => _uploadBytes(path, bytes));
  Future<Result<void>> remove(String path) => _call(() async {
    try {
      await _removeObject(path);
    } on StorageException catch (e) {
      if (e.statusCode != '404' &&
          e.error != 'NoSuchKey' &&
          e.error != 'not_found') {
        rethrow;
      }
    }
  });
  Future<Result<void>> confirm(String id) =>
      _write('teacher_confirm_notes_asset', {'p_asset_id': id});
  Future<Result<void>> delete(String id) =>
      _write('teacher_delete_notes_asset', {'p_asset_id': id});
  Future<Result<void>> update(String id, String title, String? subtopicId) =>
      _write('teacher_update_notes_asset', {
        'p_asset_id': id,
        'p_title': title,
        'p_subtopic_id': subtopicId,
      });
  Future<Result<void>> reorder(String topicId, List<String> ids) =>
      _write('teacher_reorder_notes', {'p_topic_id': topicId, 'p_ids': ids});
  Future<Result<void>> _write(String fn, Map<String, Object?> params) =>
      _call(() async {
        if (_object(await _rpc(fn, params))['ok'] != true) {
          throw const FormatException('ok');
        }
      });
  Future<Result<T>> _call<T>(Future<T> Function() action) async {
    try {
      return Success(await action());
    } on PostgrestException catch (e) {
      return Failure(mapPostgrestException(e));
    } on StorageException catch (e) {
      return Failure(
        AppError(
          ErrorCodes.isServerCode(e.message)
              ? e.message
              : switch (e.statusCode) {
                  '401' => ErrorCodes.notAuthenticated,
                  '403' => ErrorCodes.forbidden,
                  '404' => ErrorCodes.invalidInput,
                  _ => ErrorCodes.internal,
                },
        ),
      );
    } on FormatException {
      return const Failure(AppError(ErrorCodes.internal));
    } on Object catch (e) {
      return Failure(mapUnknownError(e));
    }
  }
}

Map<String, Object?> _object(Object? raw) =>
    raw is Map<String, Object?> ? raw : throw const FormatException('object');
String _text(Object? raw) => raw is String && raw.trim().isNotEmpty
    ? raw
    : throw const FormatException('text');
