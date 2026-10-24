import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/picked_file.dart';
import 'package:sat_east_client/features/teacher/questions/domain/services/file_picker_service.dart';

FilePickerService createFilePicker() => StubFilePickerService();

class StubFilePickerService implements FilePickerService {
  @override
  Future<Result<PickedPdf>> pickPdf() async =>
      const Failure(AppError('unsupported'));

  @override
  Future<Result<PickedFile>> pickJson() async =>
      const Failure(AppError('unsupported'));
}
