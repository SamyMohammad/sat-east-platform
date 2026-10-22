import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/picked_file.dart';

// Web/stub implementations and deterministic test fakes share this boundary.
// ignore: one_member_abstracts
abstract interface class FilePickerService {
  Future<Result<PickedFile>> pickJson();
}
