import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' show ClientException;
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Maps a GoTrue error to an [AppError]. The original message is kept for
/// logs only and must never be shown to the user.
AppError mapAuthException(AuthException e) {
  final code = switch (e.code) {
    'invalid_credentials' => ErrorCodes.invalidCredentials,
    'email_not_confirmed' => ErrorCodes.emailNotConfirmed,
    'user_already_exists' || 'email_exists' => ErrorCodes.emailTaken,
    'weak_password' => ErrorCodes.weakPassword,
    'session_not_found' ||
    'session_expired' ||
    'refresh_token_not_found' => ErrorCodes.notAuthenticated,
    'over_request_rate_limit' ||
    'over_email_send_rate_limit' => ErrorCodes.rateLimited,
    null when e is AuthSessionMissingException => ErrorCodes.notAuthenticated,
    null when e is AuthRetryableFetchException => ErrorCodes.network,
    _ => ErrorCodes.internal,
  };
  return AppError(code, e.message);
}

/// RPC exceptions reach the client as `message == <docs/07 §9 code>`.
AppError mapPostgrestException(PostgrestException e) {
  final code = ErrorCodes.isServerCode(e.message)
      ? e.message
      : ErrorCodes.internal;
  return AppError(code, e.message);
}

/// Fallback for non-Supabase errors (transport failures and the rest).
AppError mapUnknownError(Object e) {
  final code = switch (e) {
    SocketException() ||
    TimeoutException() ||
    ClientException() => ErrorCodes.network,
    _ => ErrorCodes.internal,
  };
  return AppError(code, e.toString());
}
