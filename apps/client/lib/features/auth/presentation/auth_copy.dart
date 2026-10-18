import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_state.dart';

/// User-facing copy for an error code. Raw exception text is never shown.
String authErrorCopy(String code) => switch (code) {
  ErrorCodes.invalidCredentials =>
    "That email and password don't match. Check both for typos.",
  ErrorCodes.emailNotConfirmed =>
    'Confirm your email first. Check your inbox for the link.',
  ErrorCodes.network => 'No connection. Check your internet and try again.',
  ErrorCodes.rateLimited => 'Too many attempts. Wait a minute and try again.',
  ErrorCodes.linkExpired => 'This link has expired. Request a new one.',
  ErrorCodes.weakPassword => 'Choose a stronger password.',
  _ => 'Something went wrong. Try again.',
};

String signOutReasonCopy(SignOutReason reason) => switch (reason) {
  SignOutReason.deviceRemoved =>
    'This device was removed from your account. Sign in again to continue.',
};
