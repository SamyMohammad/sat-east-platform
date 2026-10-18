import 'package:equatable/equatable.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/auth/domain/entities/app_user.dart';
import 'package:sat_east_client/features/auth/domain/entities/device.dart';

enum SignOutReason { deviceRemoved }

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => const [];
}

/// App start, before the session is restored.
final class AuthUnknown extends AuthState {
  const AuthUnknown();
}

final class AuthSignedOut extends AuthState {
  const AuthSignedOut({this.reason, this.error});

  final SignOutReason? reason;
  final AppError? error;

  @override
  List<Object?> get props => [reason, error];
}

/// Signing in, signing up or registering the device.
final class AuthBusy extends AuthState {
  const AuthBusy();
}

final class AuthRecovery extends AuthState {
  const AuthRecovery({this.error, this.saving = false});

  final AppError? error;
  final bool saving;

  @override
  List<Object?> get props => [error, saving];
}

final class AuthResetLinkSent extends AuthState {
  const AuthResetLinkSent(this.email);

  final String email;

  @override
  bool? get stringify => false;

  @override
  List<Object?> get props => [email];
}

final class AuthConfirmationSent extends AuthState {
  const AuthConfirmationSent(this.email);

  final String email;

  // Keep the email out of toString (A.6: no PII in logs).
  @override
  bool? get stringify => false;

  @override
  List<Object?> get props => [email];
}

final class AuthDeviceGate extends AuthState {
  const AuthDeviceGate({
    required this.devices,
    required this.changesLeft,
    this.error,
    this.removing = false,
  });

  final List<Device> devices;
  final int changesLeft;
  final AppError? error;
  final bool removing;

  @override
  List<Object?> get props => [devices, changesLeft, error, removing];
}

final class AuthSignedIn extends AuthState {
  const AuthSignedIn(this.user);

  final AppUser user;

  @override
  bool? get stringify => false;

  @override
  List<Object?> get props => [user];
}
