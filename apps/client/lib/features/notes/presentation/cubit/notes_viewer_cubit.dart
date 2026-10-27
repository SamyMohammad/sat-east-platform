import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/auth/domain/entities/my_profile.dart';
import 'package:sat_east_client/features/auth/domain/repositories/auth_repository.dart';
import 'package:sat_east_client/features/notes/domain/entities/notes_watermark.dart';
import 'package:sat_east_client/features/notes/domain/repositories/notes_repository.dart';
import 'package:sat_east_client/features/notes/presentation/cubit/notes_viewer_state.dart';

class NotesViewerCubit extends Cubit<NotesViewerState> {
  NotesViewerCubit(this._repository, this._auth, this._now)
    : super(const NotesViewerLoading());
  final NotesRepository _repository;
  final AuthRepository _auth;
  final DateTime Function() _now;
  final Set<String> _marked = {};
  String? _path;
  int _generation = 0;
  bool _loading = false;

  Future<void> load(String topicId, String assetId) async {
    if (isClosed) return;
    final path = '$topicId/$assetId.pdf';
    if (_path == path && (_loading || state is NotesViewerReady)) return;
    _path = path;
    _loading = true;
    final generation = ++_generation;
    emit(const NotesViewerLoading());
    final profile = await _auth.getMyProfile();
    if (isClosed || generation != _generation) return;
    if (profile case Failure(:final error)) {
      _loading = false;
      emit(NotesViewerFailed(error));
      return;
    }
    final result = await _repository.download(path);
    if (isClosed || generation != _generation) return;
    _loading = false;
    switch (result) {
      case Failure(:final error):
        emit(NotesViewerFailed(error));
      case Success(:final value):
        final info = (profile as Success<MyProfile>).value;
        final watermark = NotesWatermark(
          fullName: info.fullName,
          email: info.email,
          date: _now(),
        ).text;
        emit(NotesViewerReady(bytes: value, watermark: watermark));
        if (!_marked.add(assetId)) return;
        return _markOpened(assetId, generation);
    }
  }

  Future<void> _markOpened(String assetId, int generation) async {
    final marked = await _repository.markOpened(assetId);
    if (isClosed || generation != _generation) return;
    final current = state;
    if (marked case Failure(:final error) when current is NotesViewerReady) {
      emit(
        NotesViewerReady(
          bytes: current.bytes,
          watermark: current.watermark,
          markError: error,
        ),
      );
    }
  }

  @override
  Future<void> close() {
    if (!isClosed) {
      ++_generation;
      _marked.clear();
      _path = null;
      emit(const NotesViewerLoading());
    }
    return super.close();
  }
}
