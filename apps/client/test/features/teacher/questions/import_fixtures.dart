import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/import_report.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/picked_file.dart';
import 'package:sat_east_client/features/teacher/questions/domain/repositories/question_import_repository.dart';
import 'package:sat_east_client/features/teacher/questions/domain/services/file_picker_service.dart';

const Map<String, Object?> reportJson = {
  'ok': true,
  'rows': 2,
  'new': 1,
  'updated': 1,
  'errors': <Object?>[],
  'truncated': false,
};
final ImportReport cleanReport = ImportReport(
  ok: true,
  rows: 2,
  newCount: 1,
  updatedCount: 1,
  errors: const [],
  truncated: false,
);
final ImportReport badReport = ImportReport(
  ok: false,
  rows: 2,
  newCount: 1,
  updatedCount: 1,
  errors: const [
    ImportProblem(row: 2, externalRef: 'REF', field: 'key', problem: 'spr_key'),
  ],
  truncated: true,
);

class FakeImportRepository implements QuestionImportRepository {
  Result<ImportReport> dryResult = Success(cleanReport);
  Result<ImportReport> commitResult = Success(cleanReport);
  Future<Result<ImportReport>>? pending;
  final List<List<Object?>> dryCalls = [];
  final List<List<Object?>> commitCalls = [];
  @override
  Future<Result<ImportReport>> dryRun(List<Object?> items) async {
    dryCalls.add(items);
    return pending ?? dryResult;
  }

  @override
  Future<Result<ImportReport>> commit(List<Object?> items) async {
    commitCalls.add(items);
    return pending ?? commitResult;
  }
}

class FakeFilePicker implements FilePickerService {
  @override
  Future<Result<PickedPdf>> pickPdf() async =>
      const Failure(AppError('cancelled'));

  Result<PickedFile> result = const Success(
    PickedFile(name: 'bank.json', text: '[{"custom":[null,true,3.5]},null]'),
  );
  Future<Result<PickedFile>>? pending;
  @override
  Future<Result<PickedFile>> pickJson() async => pending ?? result;
}
