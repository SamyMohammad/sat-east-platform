import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/errors/supabase_error_mapper.dart';
import 'package:sat_east_client/features/auth/domain/entities/app_user.dart';
import 'package:sat_east_client/features/auth/domain/entities/sign_up_outcome.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// GoTrue access. Catches every exception and maps it to an [AppError].
class AuthRemoteDataSource {
  AuthRemoteDataSource(this._auth);

  final GoTrueClient _auth;

  AppUser? get currentUser => _toUser(_auth.currentUser);

  Stream<AppUser?> get userChanges => _auth.onAuthStateChange
      .map((state) => _toUser(state.session?.user))
      .handleError((Object _) {})
      .distinct();

  Future<Result<AppUser>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = _toUser(response.user ?? response.session?.user);
      if (user == null) return const Failure(AppError(ErrorCodes.internal));
      return Success(user);
    } on AuthException catch (e) {
      return Failure(mapAuthException(e));
    } on Object catch (e) {
      return Failure(mapUnknownError(e));
    }
  }

  Future<Result<SignUpOutcome>> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await _auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      );
      // Supabase enumeration protection: an existing email comes back as a
      // user with no identities and no session.
      final identities = response.user?.identities;
      if (response.session == null &&
          identities != null &&
          identities.isEmpty) {
        return const Failure(AppError(ErrorCodes.emailTaken));
      }
      return Success(
        response.session == null
            ? SignUpOutcome.confirmationSent
            : SignUpOutcome.signedIn,
      );
    } on AuthException catch (e) {
      return Failure(mapAuthException(e));
    } on Object catch (e) {
      return Failure(mapUnknownError(e));
    }
  }

  Future<Result<void>> signOut() async {
    try {
      await _auth.signOut();
      return const Success(null);
    } on AuthException catch (e) {
      return Failure(mapAuthException(e));
    } on Object catch (e) {
      return Failure(mapUnknownError(e));
    }
  }

  static AppUser? _toUser(User? user) =>
      user == null ? null : AppUser(id: user.id, email: user.email ?? '');
}
