import 'package:equatable/equatable.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/bank_row.dart';

class BankPage extends Equatable {
  BankPage({
    required this.total,
    required this.page,
    required this.pageSize,
    required List<BankRow> rows,
  }) : rows = List.unmodifiable(rows);
  final int total;
  final int page;
  final int pageSize;
  final List<BankRow> rows;
  bool get hasNext => page * pageSize < total;
  bool get hasPrevious => page > 1;
  int get start => rows.isEmpty ? 0 : (page - 1) * pageSize + 1;
  int get end => rows.isEmpty ? 0 : start + rows.length - 1;
  @override
  List<Object?> get props => [total, page, pageSize, rows];
}
