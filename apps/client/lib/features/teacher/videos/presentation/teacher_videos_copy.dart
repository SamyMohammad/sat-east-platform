import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/video/video_provider.dart';

abstract final class TeacherVideosCopy {
  static const title = 'Videos';
  static const menu = 'Videos\u2026';
  static const upload = 'Upload protected videos with the video tool.';
  static const addYoutube = 'Add YouTube video';
  static const add = 'Add';
  static const rename = 'Rename';
  static const save = 'Save';
  static const delete = 'Delete';
  static const cancel = 'Cancel';
  static const retry = 'Retry';
  static const reload = 'Reload';
  static const empty = 'No videos yet.';
  static const pending = 'Upload not finished';
  static const deleteWarning =
      'Delete this video? Students lose their progress on it.';
  static const moveUp = 'Move up';
  static const moveDown = 'Move down';
  static const titleLabel = 'Title';
  static const youtubeLabel = 'YouTube link or video id';
  static const durationLabel = 'Duration (mm:ss)';
  static const titleRequired = 'Enter a title.';
  static const youtubeRequired = 'Paste a YouTube link or video id.';
  static const durationRequired =
      'Enter a duration as mm:ss greater than zero.';

  static String provider(VideoProvider provider) => switch (provider) {
    VideoProvider.r2Hls => 'Protected',
    VideoProvider.youtube => 'YouTube',
  };
  static String duration(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  static String size(int? mb, VideoProvider provider) =>
      provider == VideoProvider.youtube || mb == null ? '\u2014 ' : '$mb MB';
  static String error(String code) => switch (code) {
    ErrorCodes.forbidden => 'Only the teacher can change the videos.',
    ErrorCodes.quotaExceeded => 'Video storage is full. Delete a video first.',
    ErrorCodes.invalidInput =>
      "That change wasn't saved. Reload and try again.",
    ErrorCodes.notAuthenticated => 'Sign in again to manage videos.',
    ErrorCodes.rateLimited => 'Too many tries. Wait a minute and retry.',
    _ => "Couldn't save. Check your connection and try again.",
  };
}
