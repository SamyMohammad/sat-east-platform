import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/observability/error_reporter.dart';
import 'package:sat_east_client/features/auth/domain/entities/app_user.dart';
import 'package:sat_east_client/features/auth/domain/entities/device_registration.dart';
import 'package:sat_east_client/features/auth/domain/entities/device_status.dart';
import 'package:sat_east_client/features/auth/domain/entities/sign_up_outcome.dart';
import 'package:sat_east_client/features/auth/domain/recovery_link.dart';
import 'package:sat_east_client/features/auth/domain/repositories/auth_repository.dart';
import 'package:sat_east_client/features/auth/domain/repositories/device_repository.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_state.dart';

/// App-wide session state: sign-in, device registration and revocation checks.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit(
    this._auth,
    this._devices,
    this._reporter, {
    Stream<void> Function(Duration)? ticker,
    Uri? initialUri,
    this._checkEvery = const Duration(seconds: 60),
  }) : _ticker = ticker ?? Stream<void>.periodic,
       _initialRecovery = RecoveryLink.parse(initialUri ?? Uri.base),
       super(const AuthUnknown());

  final AuthRepository _auth;
  final DeviceRepository _devices;
  final ErrorReporter _reporter;
  final Stream<void> Function(Duration) _ticker;
  final Duration _checkEvery;
  final RecoveryLinkResult _initialRecovery;

  StreamSubscription<void>? _tickSub;
  StreamSubscription<AppUser?>? _userSub;
  StreamSubscription<void>? _recoverySub;
  bool _startupHandled = false;
  bool _expiredRecovery = false;
  Future<void>? _pendingSignOut;
  bool _inFlight = false;

  /// True while [signOut] runs; new operations are rejected meanwhile.
  bool _signingOut = false;

  /// True while a session loss is being handled; duplicate events are dropped.
  bool _losingSession = false;

  /// Bumped by sign-out and close so in-flight work can detect it is stale.
  int _session = 0;

  /// Restores the session, registers the device, then routes by outcome.
  Future<void> start() async {
    if (isClosed) return;
    _recoverySub ??= _auth.passwordRecovery.listen(
      (_) => _onRecovery(),
      onError: _onRecoveryError,
    );
    // The SDK queues its replayed auth event when the listener subscribes.
    await Future<void>.value();
    if (isClosed) return;
    // Watch the session for the cubit's whole life: if it disappears while
    // signed in (token revoked, expired refresh), the user is signed out.
    _userSub ??= _auth.userChanges.listen(_onUserChanged);
    if (!_startupHandled) {
      _startupHandled = true;
      switch (_initialRecovery) {
        case RecoveryExpired():
          _expiredRecovery = true;
          _invalidateInFlight();
          emit(const AuthSignedOut(error: AppError(ErrorCodes.linkExpired)));
          return;
        case RecoveryRequested() || RecoveryNone():
          break;
      }
    }
    if (state is AuthRecovery || _expiredRecovery) return;
    if (_inFlight || _signingOut) return;
    final user = _auth.currentUser;
    if (user == null) {
      emit(const AuthSignedOut());
      return;
    }
    await _guarded((gen) async {
      emit(const AuthBusy());
      await _register(await _auth.getCurrentUser(), gen);
    });
  }

  Future<void> requestPasswordReset(String email) => _guarded((gen) async {
    emit(const AuthBusy());
    final result = await _auth.requestPasswordReset(email);
    if (_stale(gen)) return;
    switch (result) {
      case Success():
        _expiredRecovery = false;
        emit(AuthResetLinkSent(email));
      case Failure(:final error):
        emit(AuthSignedOut(error: error));
    }
  });

  Future<void> setNewPassword(String password) async {
    if (state is! AuthRecovery) return;
    await _guarded((gen) async {
      emit(const AuthRecovery(saving: true));
      final result = await _auth.updatePassword(password);
      if (_stale(gen)) return;
      switch (result) {
        case Success():
          await _register(await _auth.getCurrentUser(), gen);
        case Failure(:final error):
          if (error.code == ErrorCodes.notAuthenticated ||
              error.code == ErrorCodes.linkExpired) {
            _expiredRecovery = true;
            emit(const AuthSignedOut(error: AppError(ErrorCodes.linkExpired)));
          } else {
            emit(AuthRecovery(error: error));
          }
      }
    });
  }

  void _onRecovery() {
    if (isClosed || _signingOut || _expiredRecovery || state is AuthRecovery) {
      return;
    }
    _invalidateInFlight();
    unawaited(_cancelTicker());
    emit(const AuthRecovery());
  }

  void _onRecoveryError(Object error) {
    if (isClosed || _signingOut) return;
    final failure = error is AppError
        ? error
        : const AppError(ErrorCodes.internal);
    if (state is! AuthRecovery &&
        !(state is AuthUnknown && failure.code == ErrorCodes.linkExpired)) {
      return;
    }
    _invalidateInFlight();
    if (failure.code == ErrorCodes.linkExpired ||
        failure.code == ErrorCodes.notAuthenticated) {
      _expiredRecovery = true;
      emit(const AuthSignedOut(error: AppError(ErrorCodes.linkExpired)));
    } else {
      emit(AuthRecovery(error: failure));
    }
  }

  Future<void> signIn(String email, String password) => _guarded((gen) async {
    emit(const AuthBusy());
    final result = await _auth.signIn(email: email, password: password);
    if (_stale(gen)) return;
    switch (result) {
      case Success(:final value):
        await _register(value, gen);
      case Failure(:final error):
        emit(AuthSignedOut(error: error));
    }
  });

  Future<void> signUp(String email, String password, String fullName) =>
      _guarded((gen) async {
        emit(const AuthBusy());
        final result = await _auth.signUp(
          email: email,
          password: password,
          fullName: fullName,
        );
        if (_stale(gen)) return;
        switch (result) {
          case Success(value: SignUpOutcome.confirmationSent):
            emit(AuthConfirmationSent(email));
          case Success(value: SignUpOutcome.signedIn):
            await _register(await _auth.getCurrentUser(), gen);
          case Failure(:final error):
            emit(AuthSignedOut(error: error));
        }
      });

  Future<void> removeDevice(String deviceId) async {
    final gate = state;
    if (gate is! AuthDeviceGate) return;
    await _guarded((gen) async {
      emit(
        AuthDeviceGate(
          devices: gate.devices,
          changesLeft: gate.changesLeft,
          removing: true,
        ),
      );
      final result = await _devices.remove(deviceId);
      if (_stale(gen)) return;
      switch (result) {
        case Success():
          await _register(await _auth.getCurrentUser(), gen);
        case Failure(:final error):
          emit(
            AuthDeviceGate(
              devices: gate.devices,
              changesLeft: error.code == ErrorCodes.deviceLimit
                  ? 0
                  : gate.changesLeft,
              error: error,
            ),
          );
      }
    });
  }

  /// Revocation check (timer tick or app resume). Only when signed in.
  Future<void> checkDevice() async {
    final current = state;
    if (current is! AuthSignedIn) return;
    await _guarded((gen) async {
      final result = await _devices.status();
      if (_stale(gen)) return;
      // A transient failure must never sign the user out, except a lost
      // session (not_authenticated), which is not transient.
      if (result is Failure<DeviceStatus>) {
        if (result.error.code == ErrorCodes.notAuthenticated) await signOut();
        return;
      }
      if (result is! Success<DeviceStatus>) return;
      switch (result.value) {
        case DeviceStatus.active:
          return;
        case DeviceStatus.revoked:
          await signOut(SignOutReason.deviceRemoved);
        case DeviceStatus.unknown:
          // Same rule: if re-registering fails (e.g. network), stay signed in.
          await _register(current.user, gen, keepStateOnFailure: true);
      }
    });
  }

  /// Drops a stale error (keeps the sign-out reason). SignedOut only.
  void clearError() {
    final current = state;
    if (current is AuthSignedOut && current.error != null) {
      _expiredRecovery = false;
      emit(AuthSignedOut(reason: current.reason));
    }
  }

  /// Leaves the check-inbox screen: back to the signed-out state.
  void acknowledgeConfirmation() {
    if (state is AuthConfirmationSent || state is AuthResetLinkSent) {
      emit(const AuthSignedOut());
    }
  }

  /// Overlapping calls share one sign-out; the first reason wins.
  Future<void> signOut([SignOutReason? reason]) => _pendingSignOut ??= _signOut(
    reason,
  ).whenComplete(() => _pendingSignOut = null);

  Future<void> _signOut(SignOutReason? reason) async {
    _signingOut = true;
    _invalidateInFlight();
    try {
      await _cancelTicker();
      // Repository error ignored: the UI signs out regardless.
      await _auth.signOut();
      // Not an emit, so it runs even if the cubit was closed meanwhile.
      await _reporter.clearUser();
      if (isClosed) return;
      emit(AuthSignedOut(reason: reason));
    } finally {
      _signingOut = false;
    }
  }

  void _onUserChanged(AppUser? user) {
    // Our own sign-out also emits null; it handles its own state.
    if (user != null || _signingOut || _losingSession) return;
    final current = state;
    if (current is AuthSignedIn ||
        current is AuthDeviceGate ||
        current is AuthRecovery ||
        current is AuthConfirmationSent) {
      unawaited(_sessionLost(_session));
    }
  }

  Future<void> _sessionLost(int gen) async {
    // Defensive: only guards against close. Duplicate events are dropped by
    // [_losingSession] in [_onUserChanged], not by this check.
    if (_stale(gen)) return;
    final recovering = state is AuthRecovery;
    _losingSession = true;
    _invalidateInFlight();
    final mine = _session;
    Object? failure;
    StackTrace? failureTrace;
    try {
      await _cancelTicker();
      await _reporter.clearUser();
    } on Object catch (e, st) {
      // Cleanup failed, but the session is gone: the user must still be
      // signed out. Report after emitting.
      failure = e;
      failureTrace = st;
    }
    try {
      if (!_stale(mine)) {
        _expiredRecovery = recovering;
        emit(
          AuthSignedOut(
            error: recovering ? const AppError(ErrorCodes.linkExpired) : null,
          ),
        );
      }
    } finally {
      _losingSession = false;
    }
    if (failure != null) {
      await _reporter.captureError(
        failure,
        failureTrace,
        hint: 'AuthCubit session loss cleanup',
      );
    }
  }

  @override
  Future<void> close() async {
    _invalidateInFlight();
    await _userSub?.cancel();
    _userSub = null;
    await _recoverySub?.cancel();
    _recoverySub = null;
    await _cancelTicker();
    return super.close();
  }

  /// Makes every running operation stale and frees the in-flight guard.
  void _invalidateInFlight() {
    _session++;
    _inFlight = false;
  }

  bool _stale(int gen) => isClosed || gen != _session;

  Future<void> _guarded(Future<void> Function(int gen) body) async {
    if (isClosed || _inFlight || _signingOut || _losingSession) return;
    _inFlight = true;
    final gen = _session;
    try {
      await body(gen);
    } finally {
      // After a sign-out the guard belongs to a newer operation.
      if (gen == _session) _inFlight = false;
    }
  }

  Future<void> _register(
    AppUser? user,
    int gen, {
    bool keepStateOnFailure = false,
  }) async {
    if (_stale(gen)) return;
    if (user == null) {
      await _cancelTicker();
      if (_stale(gen)) return;
      emit(const AuthSignedOut(error: AppError(ErrorCodes.notAuthenticated)));
      return;
    }
    final result = await _devices.register();
    if (_stale(gen)) return;
    switch (result) {
      case Success(value: DeviceAllowed()):
        await _reporter.setUser(user.id);
        if (_stale(gen)) return;
        emit(AuthSignedIn(user));
        _startTicker();
      case Success(
        value: DeviceLimitReached(:final devices, :final changesLeft),
      ):
        await _cancelTicker();
        if (_stale(gen)) return;
        emit(AuthDeviceGate(devices: devices, changesLeft: changesLeft));
      case Failure(:final error):
        if (keepStateOnFailure) return;
        await _cancelTicker();
        if (_stale(gen)) return;
        emit(AuthSignedOut(error: error));
    }
  }

  void _startTicker() {
    unawaited(_tickSub?.cancel());
    _tickSub = _ticker(_checkEvery).listen((_) => unawaited(checkDevice()));
  }

  Future<void> _cancelTicker() async {
    final sub = _tickSub;
    _tickSub = null;
    await sub?.cancel();
  }
}
