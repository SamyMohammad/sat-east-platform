import 'package:sat_east_client/core/errors/result.dart';

// Domain port for the optional Home expiry warning setting.
// ignore: one_member_abstracts
abstract interface class HomeSettingsRepository {
  Future<Result<int>> expiryWarnDays();
}
