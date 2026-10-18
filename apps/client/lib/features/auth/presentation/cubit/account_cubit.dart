import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/auth/domain/entities/device.dart';
import 'package:sat_east_client/features/auth/domain/repositories/auth_repository.dart';
import 'package:sat_east_client/features/auth/domain/repositories/device_repository.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/account_state.dart';

class AccountCubit extends Cubit<AccountState> {
  AccountCubit(this._auth, this._devices) : super(const AccountLoading());

  final AuthRepository _auth;
  final DeviceRepository _devices;
  bool _inFlight = false;

  Future<void> load() => _run(() async {
    emit(const AccountLoading());
    final profile = await _auth.getMyProfile();
    if (isClosed) return;
    switch (profile) {
      case Failure(:final error):
        emit(AccountError(error));
      case Success(value: final info):
        final devices = await _devices.listMine();
        if (isClosed) return;
        switch (devices) {
          case Failure(:final error):
            emit(AccountError(error));
          case Success(:final value):
            final enrollments = await _auth.listMyEnrollments();
            if (isClosed) return;
            switch (enrollments) {
              case Failure(:final error):
                emit(AccountError(error));
              case Success(value: final courses):
                emit(
                  AccountLoaded(
                    info,
                    value.devices,
                    value.changesLeft,
                    enrollments: courses,
                  ),
                );
            }
        }
    }
  });

  Future<void> changePassword(String password) async {
    final current = state;
    if (current is! AccountLoaded || current.busy) return;
    await _run(() async {
      _emitLoaded(current, busy: true);
      final result = await _auth.updatePassword(password);
      if (isClosed) return;
      switch (result) {
        case Success():
          _emitLoaded(current, passwordSaved: true);
        case Failure(:final error):
          _emitLoaded(current, error: error);
      }
    });
  }

  Future<void> removeDevice(String id) async {
    final current = state;
    if (current is! AccountLoaded || current.busy || current.changesLeft <= 0) {
      return;
    }
    if (!current.devices.any((d) => d.id == id && !d.isCurrent)) return;
    await _run(() async {
      _emitLoaded(current, busy: true);
      final result = await _devices.remove(id);
      if (isClosed) return;
      switch (result) {
        case Failure(:final error):
          _emitLoaded(
            current,
            error: error,
            changesLeft: error.code == ErrorCodes.deviceLimit
                ? 0
                : current.changesLeft,
          );
        case Success(value: final allowance):
          final refreshed = await _devices.listMine();
          if (isClosed) return;
          switch (refreshed) {
            case Success(:final value):
              _emitLoaded(
                current,
                devices: value.devices,
                changesLeft: value.changesLeft,
              );
            case Failure(:final error):
              _emitLoaded(
                current,
                devices: current.devices.where((d) => d.id != id).toList(),
                changesLeft: allowance,
                error: error,
              );
          }
      }
    });
  }

  void _emitLoaded(
    AccountLoaded current, {
    List<Device>? devices,
    int? changesLeft,
    bool busy = false,
    AppError? error,
    bool passwordSaved = false,
  }) {
    if (isClosed) return;
    emit(
      AccountLoaded(
        current.profile,
        devices ?? current.devices,
        changesLeft ?? current.changesLeft,
        enrollments: current.enrollments,
        busy: busy,
        error: error,
        passwordSaved: passwordSaved,
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (isClosed || _inFlight) return;
    _inFlight = true;
    try {
      await action();
    } finally {
      _inFlight = false;
    }
  }
}
