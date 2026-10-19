import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/catalogue/domain/repositories/catalogue_repository.dart';
import 'package:sat_east_client/features/catalogue/presentation/cubit/catalogue_state.dart';

class CatalogueCubit extends Cubit<CatalogueState> {
  CatalogueCubit(this._repository) : super(const CatalogueLoading());

  final CatalogueRepository _repository;

  Future<void> load() async {
    if (isClosed) return;

    emit(const CatalogueLoading());
    final result = await _repository.getCatalogue();
    if (isClosed) return;
    switch (result) {
      case Success(:final value):
        emit(CatalogueLoaded(value));
      case Failure(:final error):
        emit(CatalogueFailed(error));
    }
  }

  Future<void> retry() async {
    await load();
  }
}
