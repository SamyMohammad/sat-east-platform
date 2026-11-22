import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/picked_video.dart';
import 'package:sat_east_client/features/teacher/videos/domain/services/video_picker.dart';

VideoPicker createVideoPicker() => const UnsupportedVideoPicker();

class UnsupportedVideoPicker implements VideoPicker {
  const UnsupportedVideoPicker();

  @override
  bool get isSupported => false;

  @override
  Future<Result<PickedVideo>> pick() async =>
      const Failure(AppError(ErrorCodes.unsupported));
}
