import 'package:equatable/equatable.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/activation/domain/entities/activation_result.dart';

sealed class ActivationState extends Equatable {
  const ActivationState();

  @override
  List<Object?> get props => const [];
}

final class ActivationIdle extends ActivationState {
  const ActivationIdle();
}

final class ActivationSubmitting extends ActivationState {
  const ActivationSubmitting();
}

final class ActivationDone extends ActivationState {
  const ActivationDone(this.result);

  final ActivationResult result;

  @override
  List<Object?> get props => [result];
}

final class ActivationFailed extends ActivationState {
  const ActivationFailed(this.error);

  final AppError error;

  @override
  List<Object?> get props => [error];
}
