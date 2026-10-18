import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/errors/supabase_error_mapper.dart';
import 'package:sat_east_client/features/auth/domain/entities/app_user.dart';
import 'package:sat_east_client/features/auth/domain/entities/my_profile.dart';
import 'package:sat_east_client/features/auth/domain/entities/sign_up_outcome.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// GoTrue access. Catches every exception and maps it to an [AppError].
class AuthRemoteDataSource {
  AuthRemoteDataSource(
    this._auth, {
    required this._client,
    bool isWeb = kIsWeb,
    Uri? baseUri,
  }) : _resetRedirectTo = isWeb
           ? '${(baseUri ?? Uri.base).origin}/?flow=recovery'
           : null;

  final GoTrueClient _auth;
  final SupabaseClient _client;
  final String? _resetRedirectTo;

  AppUser? get currentUser => _toUser(_auth.currentUser);

  Stream<AppUser?> get userChanges => _auth.onAuthStateChange
      .map((state) => _toUser(state.session?.user))
      .handleError((Object _) {})
      .distinct();

  Stream<void> get passwordRecovery => _auth.onAuthStateChange.transform(
    StreamTransformer<AuthState, void>.fromHandlers(
      handleData: (state, sink) {
        if (state.event == AuthChangeEvent.passwordRecovery) sink.add(null);
      },
      handleError: (error, stack, sink) {
        final mapped = switch (error) {
          AuthPKCEGrantCodeExchangeError() => const AppError(
            ErrorCodes.linkExpired,
          ),
          AuthException(
            code: 'otp_expired' ||
                'access_denied' ||
                'flow_state_expired' ||
                'flow_state_not_found',
          ) =>
            const AppError(ErrorCodes.linkExpired),
          AuthException() => mapAuthException(error),
          _ => mapUnknownError(error),
        };
        sink.addError(mapped, stack);
      },
    ),
  );

  Future<Result<void>> requestPasswordReset(String email) async {
    try {
      await _auth.resetPasswordForEmail(email, redirectTo: _resetRedirectTo);
      return const Success(null);
    } on AuthException catch (e) {
      if (e.code == 'user_not_found') return const Success(null);
      return Failure(mapAuthException(e));
    } on Object catch (e) {
      return Failure(mapUnknownError(e));
    }
  }

  Future<Result<void>> updatePassword(String password) async {
    try {
      await _auth.updateUser(UserAttributes(password: password));
      return const Success(null);
    } on AuthException catch (e) {
      return Failure(mapAuthException(e));
    } on Object catch (e) {
      return Failure(mapUnknownError(e));
    }
  }

  Future<Result<MyProfile>> getMyProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return const Failure(AppError(ErrorCodes.notAuthenticated));
      }
      final email = user.email;
      if (email == null || email.isEmpty) {
        return const Failure(AppError(ErrorCodes.internal));
      }
      final profile = await _client
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .single();
      final fullName = profile['full_name'];
      if (fullName is! String) {
        return const Failure(AppError(ErrorCodes.internal));
      }
      return Success(MyProfile(fullName: fullName, email: email));
    } on PostgrestException catch (e) {
      return Failure(mapPostgrestException(e));
    } on AuthException catch (e) {
      return Failure(mapAuthException(e));
    } on Object catch (e) {
      return Failure(mapUnknownError(e));
    }
  }

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
