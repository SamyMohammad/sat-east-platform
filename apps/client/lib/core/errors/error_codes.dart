/// Error codes from `docs/07` §9 plus client-only auth/transport codes.
abstract final class ErrorCodes {
  static const notAuthenticated = 'not_authenticated';
  static const forbidden = 'forbidden';
  static const invalidInput = 'invalid_input';
  static const inUse = 'in_use';
  static const versionConflict = 'version_conflict';
  static const deviceLimit = 'device_limit';
  static const deviceRevoked = 'device_revoked';
  static const rateLimited = 'rate_limited';
  static const internal = 'internal';
  static const notEnrolled = 'not_enrolled';
  static const accessExpired = 'access_expired';
  static const topicLocked = 'topic_locked';
  static const poolExhausted = 'pool_exhausted';
  static const practiceNeeded = 'practice_needed';
  static const homeworkNeeded = 'homework_needed';
  static const attemptClosed = 'attempt_closed';
  static const attemptNotSubmitted = 'attempt_not_submitted';
  static const notesNeeded = 'notes_needed';
  static const videoNeeded = 'video_needed';
  static const quotaExceeded = 'quota_exceeded';
  static const cooldownActive = 'cooldown_active';
  static const deadlinePassed = 'deadline_passed';
  static const codeInvalid = 'code_invalid';
  static const codeUsed = 'code_used';
  static const alreadyEnrolled = 'already_enrolled';

  // Client-only (GoTrue / transport).
  static const invalidCredentials = 'invalid_credentials';
  static const emailNotConfirmed = 'email_not_confirmed';
  static const emailTaken = 'email_taken';
  static const weakPassword = 'weak_password';
  static const linkExpired = 'link_expired';
  static const network = 'network';
  static const unsupported = 'unsupported';

  /// The user dismissed a picker; callers keep their previous state.
  static const cancelled = 'cancelled';

  // Client-only notes upload checks (UX; the bucket re-validates).
  static const notesPdfRequired = 'notes_pdf_required';
  static const notesTooLarge = 'notes_too_large';
  static const notesInvalidPdf = 'notes_invalid_pdf';
  static const notesCleanupFailed = 'notes_cleanup_failed';

  static const _serverCodes = <String>{
    notAuthenticated,
    forbidden,
    invalidInput,
    inUse,
    versionConflict,
    deviceLimit,
    deviceRevoked,
    rateLimited,
    internal,
    notEnrolled,
    accessExpired,
    topicLocked,
    poolExhausted,
    practiceNeeded,
    homeworkNeeded,
    attemptClosed,
    attemptNotSubmitted,
    notesNeeded,
    videoNeeded,
    quotaExceeded,
    cooldownActive,
    deadlinePassed,
    codeInvalid,
    codeUsed,
    alreadyEnrolled,
  };

  /// Whether [code] is a `docs/07` §9 server code.
  static bool isServerCode(String code) => _serverCodes.contains(code);
}
