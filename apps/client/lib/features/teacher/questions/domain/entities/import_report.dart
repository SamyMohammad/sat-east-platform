import 'package:equatable/equatable.dart';

class ImportProblem extends Equatable {
  const ImportProblem({
    required this.row,
    required this.externalRef,
    required this.field,
    required this.problem,
  });
  final int row;
  final String? externalRef;
  final String field;
  final String problem;
  @override
  List<Object?> get props => [row, externalRef, field, problem];
}

class ImportReport extends Equatable {
  ImportReport({
    required this.ok,
    required this.rows,
    required this.newCount,
    required this.updatedCount,
    required List<ImportProblem> errors,
    required this.truncated,
  }) : errors = List.unmodifiable(errors);
  final bool ok;
  final int rows;
  final int newCount;
  final int updatedCount;
  final List<ImportProblem> errors;
  final bool truncated;
  bool get canCommit => ok && errors.isEmpty && !truncated;
  @override
  List<Object?> get props => [
    ok,
    rows,
    newCount,
    updatedCount,
    errors,
    truncated,
  ];
}
