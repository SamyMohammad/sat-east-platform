import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/home/domain/usecases/get_home_summary.dart';
import 'package:sat_east_client/features/home/presentation/cubit/home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  HomeCubit(this._getSummary) : super(const HomeLoading());
  final GetHomeSummary _getSummary;
  int _loadVersion = 0;

  Future<void> load() async {
    if (isClosed) return;
    final version = ++_loadVersion;
    emit(const HomeLoading());
    final result = await _getSummary();
    if (isClosed || version != _loadVersion) return;
    switch (result) {
      case Success(:final value):
        emit(HomeLoaded(value));
      case Failure(:final error):
        emit(HomeFailed(error));
    }
  }

  Future<void> retry() => load();
}
