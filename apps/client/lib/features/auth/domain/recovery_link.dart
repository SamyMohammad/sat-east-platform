abstract final class RecoveryLink {
  static RecoveryLinkResult parse(Uri uri) {
    final query = uri.queryParameters;
    final fragment = Uri.splitQueryString(uri.fragment);
    for (final parameters in [query, fragment]) {
      if (parameters['error_code'] == 'otp_expired' ||
          parameters['error'] == 'access_denied') {
        return const RecoveryExpired();
      }
    }
    if (query['flow'] == 'recovery' || fragment['flow'] == 'recovery') {
      return const RecoveryRequested();
    }
    return const RecoveryNone();
  }
}

sealed class RecoveryLinkResult {
  const RecoveryLinkResult();
}

final class RecoveryNone extends RecoveryLinkResult {
  const RecoveryNone();
}

final class RecoveryRequested extends RecoveryLinkResult {
  const RecoveryRequested();
}

final class RecoveryExpired extends RecoveryLinkResult {
  const RecoveryExpired();
}
