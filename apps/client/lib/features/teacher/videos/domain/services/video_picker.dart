import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/picked_video.dart';

abstract interface class VideoPicker {
  /// False where there is no browser file chooser (everything but web).
  bool get isSupported;

  /// Opens the platform file chooser. Failure codes: `cancelled`,
  /// `unsupported` (no browser), `internal`.
  Future<Result<PickedVideo>> pick();
}
