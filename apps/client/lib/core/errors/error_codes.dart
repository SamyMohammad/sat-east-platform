/// Error codes from `docs/07` §9 plus client-only auth/transport codes.
abstract final class ErrorCodes {
  static const notAuthenticated = 'not_authenticated';
  static const forbidden = 'forbidden';
  static const invalidInput = 'invalid_input';
  static const deviceLimit = 'device_limit';
  static const rateLimited = 'rate_limited';
  static const internal = 'internal';
  static const notEnrolled = 'not_enrolled';
  static const accessExpired = 'access_expired';
  static const topicLocked = 'topic_locked';

  // Client-only (GoTrue / transport).
  static const invalidCredentials = 'invalid_credentials';
  static const emailNotConfirmed = 'email_not_confirmed';
  static const emailTaken = 'email_taken';
  static const weakPassword = 'weak_password';
  static const network = 'network';

  static const _serverCodes = <String>{
    notAuthenticated,
    forbidden,
    invalidInput,
    deviceLimit,
    rateLimited,
    internal,
    notEnrolled,
    accessExpired,
    topicLocked,
  };

  /// Whether [code] is a `docs/07` §9 server code.
  static bool isServerCode(String code) => _serverCodes.contains(code);
}
