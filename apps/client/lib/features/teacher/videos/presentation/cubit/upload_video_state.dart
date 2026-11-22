import 'package:equatable/equatable.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/picked_video.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/video_upload.dart';

sealed class UploadVideoState extends Equatable {
  const UploadVideoState();
  @override
  List<Object?> get props => const [];
}

/// No browser file chooser (mobile/desktop build): uploads are web-only.
final class UploadVideoUnsupported extends UploadVideoState {
  const UploadVideoUnsupported();
}

/// Waiting for the teacher. [limits] is null until read (or if unreadable,
/// since the server enforces them anyway).
final class UploadVideoIdle extends UploadVideoState {
  const UploadVideoIdle({this.file, this.limits, this.error});
  final PickedVideo? file;
  final VideoUploadLimits? limits;

  /// A file chooser problem (never an upload failure).
  final AppError? error;
  @override
  List<Object?> get props => [file, limits, error];
}

final class UploadVideoPicking extends UploadVideoState {
  const UploadVideoPicking({this.file, this.limits});
  final PickedVideo? file;
  final VideoUploadLimits? limits;
  @override
  List<Object?> get props => [file, limits];
}

/// Checking, transcoding (fraction), uploading (done/total) or finalizing.
final class UploadVideoRunning extends UploadVideoState {
  const UploadVideoRunning(this.progress, {this.cancelling = false});
  final PublishProgress progress;
  final bool cancelling;
  @override
  List<Object?> get props => [progress, cancelling];
}

final class UploadVideoSuccess extends UploadVideoState {
  const UploadVideoSuccess(this.video);
  final PublishedVideo video;
  @override
  List<Object?> get props => [video];
}

final class UploadVideoError extends UploadVideoState {
  const UploadVideoError(this.error, {this.file, this.limits});
  final AppError error;
  final PickedVideo? file;
  final VideoUploadLimits? limits;
  @override
  List<Object?> get props => [error, file, limits];
}
