import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/bank_filter.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/bank_page.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/topic_option.dart';

abstract interface class QuestionBankRepository {
  Future<Result<BankPage>> list(BankFilter filter, int page);
  Future<Result<List<BankCourse>>> topics();
}
