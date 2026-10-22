import 'dart:async';
import 'dart:js_interop';

import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/picked_file.dart';
import 'package:sat_east_client/features/teacher/questions/domain/services/file_picker_service.dart';
import 'package:web/web.dart' as web;

FilePickerService createFilePicker() => WebFilePickerService();

class WebFilePickerService implements FilePickerService {
  @override
  Future<Result<PickedFile>> pickJson() async {
    final result = Completer<Result<PickedFile>>();
    final input = web.HTMLInputElement()
      ..type = 'file'
      ..accept = '.json,application/json';
    final reader = web.FileReader();
    void finish(Result<PickedFile> value) {
      if (!result.isCompleted) result.complete(value);
    }

    final change = ((web.Event event) {
      final file = input.files?.item(0);
      if (file == null) {
        finish(const Failure(AppError(ErrorCodes.cancelled)));
        return;
      }
      reader.readAsText(file);
    }).toJS;
    final cancel = ((web.Event event) => finish(
      const Failure(AppError(ErrorCodes.cancelled)),
    )).toJS;
    final load = ((web.Event event) {
      final file = input.files?.item(0);
      final text = reader.result.dartify();
      if (file == null || text is! String) {
        finish(const Failure(AppError(ErrorCodes.internal)));
        return;
      }
      finish(Success(PickedFile(name: file.name, text: text)));
    }).toJS;
    final error = ((web.Event event) => finish(
      const Failure(AppError(ErrorCodes.internal)),
    )).toJS;
    input
      ..addEventListener('change', change)
      ..addEventListener('cancel', cancel);
    reader
      ..addEventListener('load', load)
      ..addEventListener('error', error)
      ..addEventListener('abort', cancel);
    try {
      input.click();
      return await result.future;
    } on Object {
      return const Failure(AppError(ErrorCodes.internal));
    } finally {
      input
        ..removeEventListener('change', change)
        ..removeEventListener('cancel', cancel);
      reader
        ..removeEventListener('load', load)
        ..removeEventListener('error', error)
        ..removeEventListener('abort', cancel);
      input.remove();
    }
  }
}
