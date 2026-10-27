import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/questions/data/datasources/question_bank_remote_data_source.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/bank_filter.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/bank_page.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/topic_option.dart';
import 'package:sat_east_client/features/teacher/questions/domain/repositories/question_bank_repository.dart';

class QuestionBankRepositoryImpl implements QuestionBankRepository {
  QuestionBankRepositoryImpl(this._source);
  final QuestionBankRemoteDataSource _source;
  @override
  Future<Result<BankPage>> list(BankFilter filter, int page) =>
      _source.list(filter, page);
  @override
  Future<Result<List<BankCourse>>> topics() => _source.topics();
}
