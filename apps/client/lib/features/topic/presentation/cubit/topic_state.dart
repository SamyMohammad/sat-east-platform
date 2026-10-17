import 'package:equatable/equatable.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_detail.dart';

sealed class TopicState extends Equatable {
  const TopicState();

  @override
  List<Object?> get props => const [];
}

final class TopicLoading extends TopicState {
  const TopicLoading();
}

final class TopicLoaded extends TopicState {
  const TopicLoaded(this.topic);

  final TopicDetail topic;

  @override
  List<Object?> get props => [topic];
}

final class TopicFailed extends TopicState {
  const TopicFailed(this.error);

  final AppError error;

  @override
  List<Object?> get props => [error];
}
