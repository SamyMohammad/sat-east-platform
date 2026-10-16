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

  /// Restores the session, registers the device, then routes by outcome.
  Future<void> start() async {
    if (_inFlight) return;
    final user = _auth.currentUser;
    if (user == null) {
      emit(const AuthSignedOut());
      return;
    }
    await _guarded(() async {
      emit(const AuthBusy());
      await _register(user);
    });
  }

  Future<void> signIn(String email, String password) => _guarded(() async {
    emit(const AuthBusy());
    final result = await _auth.signIn(email: email, password: password);
    if (isClosed) return;
    switch (result) {
      case Success(:final value):
        await _register(value);
      case Failure(:final error):
        emit(AuthSignedOut(error: error));
    }
  });

  Future<void> signUp(String email, String password, String fullName) =>
      _guarded(() async {
        emit(const AuthBusy());
        final result = await _auth.signUp(
          email: email,
          password: password,
          fullName: fullName,
        );
        if (isClosed) return;
        switch (result) {
          case Success(value: SignUpOutcome.confirmationSent):
            emit(AuthConfirmationSent(email));
          case Success(value: SignUpOutcome.signedIn):
            await _register(_auth.currentUser);
          case Failure(:final error):
            emit(AuthSignedOut(error: error));
        }
      });

  Future<void> removeDevice(String deviceId) async {
    final gate = state;
    if (gate is! AuthDeviceGate) return;
    await _guarded(() async {
      emit(
        AuthDeviceGate(
          devices: gate.devices,
          changesLeft: gate.changesLeft,
          removing: true,
        ),
      );
      final result = await _devices.remove(deviceId);
      if (isClosed) return;
      switch (result) {
        case Success():
          await _register(_auth.currentUser);
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
    await _guarded(() async {
      final result = await _devices.status();
      if (isClosed) return;
      // A transient failure must not sign the user out.
      if (result is! Success<DeviceStatus>) return;
      switch (result.value) {
        case DeviceStatus.active:
          return;
        case DeviceStatus.revoked:
          await signOut(SignOutReason.deviceRemoved);
        case DeviceStatus.unknown:
          await _register(current.user, keepStateOnFailure: true);
      }
    });
  }

  Future<void> signOut([SignOutReason? reason]) async {
    await _cancelTicker();
    // Repository error ignored: the UI signs out regardless.
    await _auth.signOut();
    if (isClosed) return;
    await _reporter.clearUser();
    if (isClosed) return;
    emit(AuthSignedOut(reason: reason));
  }

  @override
  Future<void> close() async {
    await _cancelTicker();
    return super.close();
  }

  Future<void> _guarded(Future<void> Function() body) async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      await body();
    } finally {
      _inFlight = false;
    }
  }

  Future<void> _register(
    AppUser? user, {
    bool keepStateOnFailure = false,
  }) async {
    final result = await _devices.register();
    if (isClosed) return;
    switch (result) {
      case Success(value: DeviceAllowed()):
        if (user == null) {
          await _cancelTicker();
          if (isClosed) return;
          emit(const AuthSignedOut());
          return;
        }
        await _reporter.setUser(user.id);
        if (isClosed) return;
        emit(AuthSignedIn(user));
        _startTicker();
      case Success(
        value: DeviceLimitReached(:final devices, :final changesLeft),
      ):
        await _cancelTicker();
        if (isClosed) return;
        emit(AuthDeviceGate(devices: devices, changesLeft: changesLeft));
      case Failure(:final error):
        if (keepStateOnFailure) return;
        await _cancelTicker();
        if (isClosed) return;
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
