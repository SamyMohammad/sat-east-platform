import 'dart:async';
import 'dart:js_interop';

import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/picked_video.dart';
import 'package:sat_east_client/features/teacher/videos/domain/services/video_picker.dart';
import 'package:web/web.dart' as web;

VideoPicker createVideoPicker() => WebVideoPicker();

/// Native file chooser. Unlike the PDF/JSON pickers the file is never read
/// into Dart: the transcoder mounts the browser `File` directly (WORKERFS).
class WebVideoPicker implements VideoPicker {
  @override
  bool get isSupported => true;

  @override
  Future<Result<PickedVideo>> pick() async {
    final result = Completer<Result<PickedVideo>>();
    final input = web.HTMLInputElement()
      ..type = 'file'
      ..accept = 'video/*,.mp4,.mov,.m4v,.mkv,.webm,.avi';
    void finish(Result<PickedVideo> value) {
      if (!result.isCompleted) result.complete(value);
    }

    final change = ((web.Event event) {
      final file = input.files?.item(0);
      if (file == null) {
        finish(const Failure(AppError(ErrorCodes.cancelled)));
        return;
      }
      finish(
        Success(
          PickedVideo(name: file.name, sizeBytes: file.size, handle: file),
        ),
      );
    }).toJS;
    final cancel = ((web.Event event) => finish(
      const Failure(AppError(ErrorCodes.cancelled)),
    )).toJS;
    input
      ..addEventListener('change', change)
      ..addEventListener('cancel', cancel);
    try {
      input.click();
      return await result.future;
    } on Object {
      return const Failure(AppError(ErrorCodes.internal));
    } finally {
      input
        ..removeEventListener('change', change)
        ..removeEventListener('cancel', cancel)
        ..remove();
    }
  }
}
