import 'package:equatable/equatable.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/home/domain/entities/home_summary.dart';

sealed class HomeState extends Equatable {
  const HomeState();
  @override
  List<Object?> get props => const [];
}

final class HomeLoading extends HomeState {
  const HomeLoading();
}

final class HomeLoaded extends HomeState {
  const HomeLoaded(this.summary);
  final HomeSummary summary;
  @override
  List<Object?> get props => [summary];
}

final class HomeFailed extends HomeState {
  const HomeFailed(this.error);
  final AppError error;
  @override
  List<Object?> get props => [error];
}
