import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/activation/domain/entities/activation_result.dart';

// A domain port keeps activation independent of its data implementation.
// ignore: one_member_abstracts
abstract interface class ActivationRepository {
  Future<Result<ActivationResult>> redeem(String code, DateTime testDate);
}
