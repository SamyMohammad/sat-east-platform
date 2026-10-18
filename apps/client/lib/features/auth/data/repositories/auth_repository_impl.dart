import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:sat_east_client/features/auth/domain/entities/app_user.dart';
import 'package:sat_east_client/features/auth/domain/entities/my_profile.dart';
import 'package:sat_east_client/features/auth/domain/entities/sign_up_outcome.dart';
import 'package:sat_east_client/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote);

  final AuthRemoteDataSource _remote;

  @override
  AppUser? get currentUser => _remote.currentUser;

  @override
  Stream<AppUser?> get userChanges => _remote.userChanges;

  @override
  Stream<void> get passwordRecovery => _remote.passwordRecovery;

  @override
  Future<Result<void>> requestPasswordReset(String email) =>
      _remote.requestPasswordReset(email);

  @override
  Future<Result<void>> updatePassword(String password) =>
      _remote.updatePassword(password);

  @override
  Future<Result<MyProfile>> getMyProfile() => _remote.getMyProfile();

  @override
  Future<Result<AppUser>> signIn({
    required String email,
    required String password,
  }) => _remote.signIn(email: email, password: password);

  @override
  Future<Result<SignUpOutcome>> signUp({
    required String email,
    required String password,
    required String fullName,
  }) => _remote.signUp(email: email, password: password, fullName: fullName);

  @override
  Future<Result<void>> signOut() => _remote.signOut();
}
