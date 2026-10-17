import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/topic/domain/repositories/topic_repository.dart';
import 'package:sat_east_client/features/topic/presentation/cubit/topic_state.dart';

class TopicCubit extends Cubit<TopicState> {
  TopicCubit(this._repository) : super(const TopicLoading());

  final TopicRepository _repository;
  int _loadVersion = 0;

  Future<void> load(String topicId) async {
    if (isClosed) return;
    final version = ++_loadVersion;
    emit(const TopicLoading());
    final result = await _repository.getTopic(topicId);
    if (isClosed || version != _loadVersion) return;
    switch (result) {
      case Success(:final value):
        emit(TopicLoaded(value));
      case Failure(:final error):
        emit(TopicFailed(error));
    }
  }
}
