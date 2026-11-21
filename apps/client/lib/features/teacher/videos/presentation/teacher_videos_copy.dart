import 'package:sat_east_client/core/errors/error_codes.dart';

abstract final class TeacherVideosCopy {
  static const title = 'Videos';
  static const menu = 'Videos\u2026';
  static const uploadVideo = 'Upload video';
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
  static const titleRequired = 'Enter a title.';

  static const protectedLabel = 'Protected';
  static String duration(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  static String size(int? mb) => mb == null ? '— ' : '$mb MB';
  static String error(String code) => switch (code) {
    ErrorCodes.forbidden => 'Only the teacher can change the videos.',
    ErrorCodes.quotaExceeded => 'Video storage is full. Delete a video first.',
    ErrorCodes.invalidInput =>
      "That change wasn't saved. Reload and try again.",
    ErrorCodes.notAuthenticated => 'Sign in again to manage videos.',
    ErrorCodes.rateLimited => 'Too many tries. Wait a minute and retry.',
    _ => "Couldn't save. Check your connection and try again.",
  };

  // Upload dialog.
  static const uploadTitle = 'Upload video';
  static const chooseFile = 'Choose video file';
  static const changeFile = 'Choose another file';
  static const noFile = 'No file chosen';
  static const keepTabOpen = 'Keep this tab open until the upload finishes.';
  static const conversionNote =
      'The video is converted in your browser first. This can take longer '
      'than the video itself.';
  static const startUpload = 'Upload';
  static const close = 'Close';
  static const done = 'Done';
  static const tryAgain = 'Try again';
  static const stopUpload = 'Stop upload';
  static const keepUploading = 'Keep uploading';
  static const stopTitle = 'Stop the upload?';
  static const stopBody =
      'Nothing will be published and the progress so far is lost.';
  static const stopping = 'Stopping…';
  static const checking = 'Checking';
  static const converting = 'Converting video';
  static const uploading = 'Uploading';
  static const finishing = 'Finishing';
  static const uploaded = 'Video uploaded.';
  static const webOnly = 'Upload videos from the web dashboard.';
  static String percent(double fraction) =>
      '${(fraction.clamp(0.0, 1.0) * 100).round()}%';
  static String files(int done, int total) => '$done of $total files';
  static String pickedFile(String name, int bytes) =>
      '$name (${fileSize(bytes)})';
  static String fileSize(int bytes) => bytes >= 1048576
      ? '${(bytes / 1048576).toStringAsFixed(1)} MB'
      : '${(bytes / 1024).ceil()} KB';
  static String limits({int? maxSourceMb, int? maxDurationS}) {
    final parts = [
      if (maxSourceMb != null) 'up to $maxSourceMb MB',
      if (maxDurationS != null) 'up to ${maxDurationS ~/ 60} min',
    ];
    return parts.isEmpty ? '' : 'Video limits: ${parts.join(', ')}.';
  }

  static String uploadError(String code) => switch (code) {
    ErrorCodes.videoTooLarge =>
      'That file is too large. Choose a smaller video.',
    ErrorCodes.videoTooLong =>
      'That video is too long. Choose a shorter video.',
    ErrorCodes.videoTranscodeFailed =>
      "Couldn't convert that video. Try a different file.",
    ErrorCodes.videoEngineLoadFailed =>
      "Couldn't load the video tools. Check your connection and try again.",
    ErrorCodes.videoUploadFailed =>
      "The upload didn't finish. Check your connection and try again.",
    ErrorCodes.videoCleanupFailed =>
      'The upload failed and a partial video may remain. Reload the list '
          'and delete it if it shows as not finished.',
    ErrorCodes.quotaExceeded => 'Video storage is full. Delete a video first.',
    ErrorCodes.unsupported => webOnly,
    ErrorCodes.invalidInput => 'Enter a title of 1 to 120 characters.',
    ErrorCodes.forbidden => 'Only the teacher can upload videos.',
    ErrorCodes.notAuthenticated => 'Sign in again to upload videos.',
    ErrorCodes.rateLimited => 'Too many tries. Wait a minute and retry.',
    _ => "Couldn't upload. Check your connection and try again.",
  };
}
