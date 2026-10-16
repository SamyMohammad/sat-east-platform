import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/observability/error_reporter.dart';
import 'package:sat_east_client/features/auth/domain/entities/app_user.dart';
import 'package:sat_east_client/features/auth/domain/entities/device_registration.dart';
import 'package:sat_east_client/features/auth/domain/entities/device_status.dart';
import 'package:sat_east_client/features/auth/domain/entities/sign_up_outcome.dart';
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
    this._checkEvery = const Duration(seconds: 60),
  }) : _ticker = ticker ?? Stream<void>.periodic,
       super(const AuthUnknown());

  final AuthRepository _auth;
  final DeviceRepository _devices;
  final ErrorReporter _reporter;
  final Stream<void> Function(Duration) _ticker;
  final Duration _checkEvery;

  StreamSubscription<void>? _tickSub;
  bool _inFlight = false;

  /// True while [signOut] runs; new operations are rejected meanwhile.
  bool _signingOut = false;

  /// Bumped by sign-out and close so in-flight work can detect it is stale.
  int _session = 0;

  /// Restores the session, registers the device, then routes by outcome.
  Future<void> start() async {
    if (_inFlight || _signingOut) return;
    final user = _auth.currentUser;
    if (user == null) {
      emit(const AuthSignedOut());
      return;
    }
    await _guarded((gen) async {
      emit(const AuthBusy());
      await _register(user, gen);
    });
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
            await _register(_auth.currentUser, gen);
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
          await _register(_auth.currentUser, gen);
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
      // A transient failure must never sign the user out.
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

  Future<void> signOut([SignOutReason? reason]) async {
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

  @override
  Future<void> close() async {
    _invalidateInFlight();
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
    if (_inFlight || _signingOut) return;
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
