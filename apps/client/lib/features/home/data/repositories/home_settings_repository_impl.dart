import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/home/data/datasources/home_settings_remote_data_source.dart';
import 'package:sat_east_client/features/home/domain/repositories/home_settings_repository.dart';

class HomeSettingsRepositoryImpl implements HomeSettingsRepository {
  HomeSettingsRepositoryImpl(this._source);
  final HomeSettingsRemoteDataSource _source;

  @override
  Future<Result<int>> expiryWarnDays() => _source.expiryWarnDays();
}
