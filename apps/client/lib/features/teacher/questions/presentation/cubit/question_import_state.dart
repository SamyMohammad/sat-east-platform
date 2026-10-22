import 'package:equatable/equatable.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/import_report.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/picked_file.dart';

sealed class QuestionImportState extends Equatable {
  const QuestionImportState();
  @override
  List<Object?> get props => const [];
}

final class ImportIdle extends QuestionImportState {
  const ImportIdle();
}

final class ImportReading extends QuestionImportState {
  const ImportReading();
}

final class ImportValidating extends QuestionImportState {
  const ImportValidating(this.file);
  final PickedFile file;
  @override
  List<Object?> get props => [file];
}

final class ImportReported extends QuestionImportState {
  const ImportReported(this.file, this.report);
  final PickedFile file;
  final ImportReport report;
  @override
  List<Object?> get props => [file, report];
}

final class ImportCommitting extends QuestionImportState {
  const ImportCommitting();
}

final class ImportCommitted extends QuestionImportState {
  const ImportCommitted(this.report);
  final ImportReport report;
  @override
  List<Object?> get props => [report];
}

final class ImportFailed extends QuestionImportState {
  const ImportFailed(this.error);
  final AppError error;
  @override
  List<Object?> get props => [error];
}
