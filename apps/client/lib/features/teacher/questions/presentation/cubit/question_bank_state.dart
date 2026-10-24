import 'package:equatable/equatable.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/bank_filter.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/bank_page.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/topic_option.dart';

class QuestionBankState extends Equatable {
  const QuestionBankState({
    this.filter = const BankFilter(),
    this.page = 1,
    this.topics = const [],
    this.bank,
    this.loading = false,
    this.error,
  });
  final BankFilter filter;
  final int page;
  final List<BankCourse> topics;
  final BankPage? bank;
  final bool loading;
  final AppError? error;
  @override
  List<Object?> get props => [filter, page, topics, bank, loading, error];
}
