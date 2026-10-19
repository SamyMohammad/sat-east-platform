import 'package:equatable/equatable.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/catalogue/domain/entities/catalogue_course.dart';

sealed class CatalogueState extends Equatable {
  const CatalogueState();

  @override
  List<Object?> get props => const [];
}

final class CatalogueLoading extends CatalogueState {
  const CatalogueLoading();
}

final class CatalogueLoaded extends CatalogueState {
  const CatalogueLoaded(this.data);

  final List<CatalogueCourse> data;

  @override
  List<Object?> get props => [data];
}

final class CatalogueFailed extends CatalogueState {
  const CatalogueFailed(this.error);

  final AppError error;

  @override
  List<Object?> get props => [error];
}
