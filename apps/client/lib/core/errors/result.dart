/// Outcome of a repository call (ADR-007 §3).
sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.error);

  final AppError error;
}

/// A failure mapped to an error code from `docs/07` §9.
class AppError {
  const AppError(this.code, [this.message]);

  final String code;
  final String? message;

  @override
  String toString() => 'AppError($code${message == null ? '' : ': $message'})';
}
