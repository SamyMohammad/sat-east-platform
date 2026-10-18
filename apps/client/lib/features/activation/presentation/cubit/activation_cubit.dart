import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/activation/domain/repositories/activation_repository.dart';
import 'package:sat_east_client/features/activation/presentation/cubit/activation_state.dart';

class ActivationCubit extends Cubit<ActivationState> {
  ActivationCubit(this._repository) : super(const ActivationIdle());

  final ActivationRepository _repository;

  Future<void> submit(String code, DateTime testDate) async {
    if (isClosed || state is ActivationSubmitting || state is ActivationDone) {
      return;
    }
    emit(const ActivationSubmitting());
    final result = await _repository.redeem(code, testDate);
    if (isClosed) return;
    switch (result) {
      case Success(:final value):
        emit(ActivationDone(value));
      case Failure(:final error):
        emit(ActivationFailed(error));
    }
  }
}
