import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/auth/domain/entities/app_user.dart';
import 'package:sat_east_client/features/auth/domain/entities/sign_up_outcome.dart';

abstract interface class AuthRepository {
  AppUser? get currentUser;
  Stream<AppUser?> get userChanges;
  Future<Result<AppUser>> signIn({
    required String email,
    required String password,
  });
  Future<Result<SignUpOutcome>> signUp({
    required String email,
    required String password,
    required String fullName,
  });
  Future<Result<void>> signOut();
}
