import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/activation/data/datasources/activation_remote_data_source.dart';
import 'package:sat_east_client/features/activation/domain/entities/activation_result.dart';
import 'package:sat_east_client/features/activation/domain/repositories/activation_repository.dart';

class ActivationRepositoryImpl implements ActivationRepository {
  ActivationRepositoryImpl(this._remote);

  final ActivationRemoteDataSource _remote;

  @override
  Future<Result<ActivationResult>> redeem(String code, DateTime testDate) =>
      _remote.redeem(code, testDate);
}
