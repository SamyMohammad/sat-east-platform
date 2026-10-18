import 'package:equatable/equatable.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/auth/domain/entities/device.dart';
import 'package:sat_east_client/features/auth/domain/entities/my_profile.dart';

sealed class AccountState extends Equatable {
  const AccountState();

  @override
  bool? get stringify => false;
}

final class AccountLoading extends AccountState {
  const AccountLoading();

  @override
  List<Object?> get props => const [];
}

final class AccountLoaded extends AccountState {
  AccountLoaded(
    this.profile,
    List<Device> devices,
    this.changesLeft, {
    this.busy = false,
    this.error,
    this.passwordSaved = false,
  }) : devices = List.unmodifiable(devices);

  final MyProfile profile;
  final List<Device> devices;
  final int changesLeft;
  final bool busy;
  final AppError? error;
  final bool passwordSaved;

  @override
  List<Object?> get props => [
    profile,
    devices,
    changesLeft,
    busy,
    error,
    passwordSaved,
  ];
}

final class AccountError extends AccountState {
  const AccountError(this.error);

  final AppError error;

  @override
  List<Object?> get props => [error];
}
