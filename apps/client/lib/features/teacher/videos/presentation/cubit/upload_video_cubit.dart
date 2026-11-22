import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/picked_video.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/video_upload.dart';
import 'package:sat_east_client/features/teacher/videos/domain/repositories/video_upload_repository.dart';
import 'package:sat_east_client/features/teacher/videos/domain/services/video_picker.dart';
import 'package:sat_east_client/features/teacher/videos/domain/usecases/publish_video.dart';
import 'package:sat_east_client/features/teacher/videos/presentation/cubit/upload_video_state.dart';

/// One upload session (one dialog). Separate from `TeacherVideosCubit`, which
/// owns the list: this one is long-running and cancellable, and holds the
/// stateful [PublishVideo] (one per upload).
class UploadVideoCubit extends Cubit<UploadVideoState> {
  UploadVideoCubit({
    required this._picker,
    required this._uploads,
    required this._publish,
  }) : super(
         _picker.isSupported
             ? const UploadVideoIdle()
             : const UploadVideoUnsupported(),
       );

  final VideoPicker _picker;
  final VideoUploadRepository _uploads;
  final PublishVideo _publish;
  PickedVideo? _file;
  VideoUploadLimits? _limits;
  bool _running = false;

  /// Reads the limits to show them. A failure only hides the hint: the
  /// server and `PublishVideo` still enforce them.
  Future<void> loadLimits() async {
    final result = await _uploads.limits();
    if (isClosed) return;
    if (result case Success(:final value)) {
      _limits = value;
      if (state case UploadVideoIdle(:final error)) {
        emit(UploadVideoIdle(file: _file, limits: _limits, error: error));
      }
    }
  }

  Future<void> pickFile() async {
    if (isClosed || _running || state is UploadVideoPicking) return;
    if (!_picker.isSupported) return;
    emit(UploadVideoPicking(file: _file, limits: _limits));
    final result = await _picker.pick();
    if (isClosed) return;
    switch (result) {
      case Success(:final value):
        _file = value;
        emit(UploadVideoIdle(file: _file, limits: _limits));
      case Failure(:final error) when error.code == ErrorCodes.cancelled:
        emit(UploadVideoIdle(file: _file, limits: _limits));
      case Failure(:final error):
        emit(UploadVideoIdle(file: _file, limits: _limits, error: error));
    }
  }

  Future<void> upload({
    required String topicId,
    required String title,
    String? subtopicId,
  }) async {
    final file = _file;
    if (isClosed || _running || file == null) return;
    _running = true;
    emit(const UploadVideoRunning(PublishChecking()));
    final result = await _publish(
      PublishVideoRequest(
        topicId: topicId,
        subtopicId: subtopicId,
        title: title,
        source: file,
      ),
      onProgress: (progress) {
        if (!isClosed && _running) emit(UploadVideoRunning(progress));
      },
    );
    _running = false;
    if (isClosed) return;
    switch (result) {
      case Success(:final value):
        emit(UploadVideoSuccess(value));
      case Failure(:final error) when error.code == ErrorCodes.cancelled:
        emit(UploadVideoIdle(file: _file, limits: _limits));
      case Failure(:final error):
        emit(UploadVideoError(error, file: _file, limits: _limits));
    }
  }

  /// Stops a running upload; `upload` then returns to idle (or reports
  /// `video_cleanup_failed` if the reservation could not be removed).
  Future<void> cancel() async {
    if (isClosed || !_running) return;
    if (state case UploadVideoRunning(:final progress)) {
      emit(UploadVideoRunning(progress, cancelling: true));
    }
    await _publish.cancel();
  }

  /// Leaves the error state, keeping the chosen file for a retry.
  void dismissError() {
    if (isClosed || state is! UploadVideoError) return;
    emit(UploadVideoIdle(file: _file, limits: _limits));
  }

  @override
  Future<void> close() async {
    if (_running) await _publish.cancel();
    return super.close();
  }
}
