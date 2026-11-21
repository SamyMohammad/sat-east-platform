import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/picked_video.dart';

/// One packaged HLS file (playlist or encrypted segment).
class HlsFile extends Equatable {
  const HlsFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;

  String get contentType =>
      name.endsWith('.m3u8') ? 'application/vnd.apple.mpegurl' : 'video/mp2t';

  @override
  List<Object?> get props => [name, bytes];
}

/// Output of the transcoder: AES-128 HLS files for the key it was given.
class TranscodedVideo extends Equatable {
  const TranscodedVideo({required this.files, required this.durationS});

  final List<HlsFile> files;

  /// Source duration in whole seconds, rounded up (as the CLI's ffprobe).
  final int durationS;

  @override
  List<Object?> get props => [files, durationS];
}

/// Client-side upload limits from `settings`. A null limit means the setting
/// is not present (not deployed yet); the server still validates (rule 2).
class VideoUploadLimits extends Equatable {
  const VideoUploadLimits({this.maxSourceMb, this.maxDurationS});

  final int? maxSourceMb;
  final int? maxDurationS;

  @override
  List<Object?> get props => [maxSourceMb, maxDurationS];
}

class PublishVideoRequest extends Equatable {
  const PublishVideoRequest({
    required this.topicId,
    required this.title,
    required this.source,
    this.subtopicId,
  });

  final String topicId;
  final String? subtopicId;
  final String title;
  final PickedVideo source;

  @override
  List<Object?> get props => [topicId, subtopicId, title, source];
}

class PublishedVideo extends Equatable {
  const PublishedVideo({
    required this.assetId,
    required this.durationS,
    required this.sizeMb,
  });

  final String assetId;
  final int durationS;
  final int sizeMb;

  @override
  List<Object?> get props => [assetId, durationS, sizeMb];
}

/// Progress of `PublishVideo`, for the upload dialog.
sealed class PublishProgress extends Equatable {
  const PublishProgress();

  @override
  List<Object?> get props => const [];
}

final class PublishChecking extends PublishProgress {
  const PublishChecking();
}

final class PublishTranscoding extends PublishProgress {
  const PublishTranscoding(this.fraction);

  /// 0..1
  final double fraction;

  @override
  List<Object?> get props => [fraction];
}

final class PublishUploading extends PublishProgress {
  const PublishUploading({required this.done, required this.total});

  final int done;
  final int total;

  @override
  List<Object?> get props => [done, total];
}

final class PublishFinalizing extends PublishProgress {
  const PublishFinalizing();
}
