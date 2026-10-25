import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/teacher_video.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/video_quota.dart';
import 'package:sat_east_client/features/teacher/videos/domain/repositories/teacher_videos_repository.dart';
import 'package:sat_east_client/features/teacher/videos/domain/video_duration.dart';
import 'package:sat_east_client/features/teacher/videos/domain/youtube_id.dart';
import 'package:sat_east_client/features/teacher/videos/presentation/cubit/teacher_videos_state.dart';

class TeacherVideosCubit extends Cubit<TeacherVideosState> {
  TeacherVideosCubit(this._repo) : super(const TeacherVideosLoading());
  final TeacherVideosRepository _repo;
  String? _topicId;
  int _generation = 0;

  Future<void> load(String topicId) async {
    if (isClosed ||
        (state is TeacherVideosReady && (state as TeacherVideosReady).busy)) {
      return;
    }
    _topicId = topicId;
    final generation = ++_generation;
    emit(const TeacherVideosLoading());
    final result = await _read(topicId);
    if (isClosed || generation != _generation) {
      return;
    }
    emit(switch (result) {
      Success(:final value) => TeacherVideosReady(value),
      Failure(:final error) => TeacherVideosFailed(error),
    });
  }

  Future<void> addYoutube({
    required String title,
    required String input,
    required int durationS,
  }) => _mutate((_) {
    final id = parseYoutubeId(input);
    if (id == null ||
        !TeacherVideo.validTitle(title) ||
        !validVideoDuration(durationS)) {
      return _invalid();
    }
    return _repo.addYoutube(_topicId!, title.trim(), id, durationS);
  });

  Future<void> rename(String assetId, String title) => _mutate((data) {
    final video = data.video(assetId);
    if (video == null || !video.ready || !TeacherVideo.validTitle(title)) {
      return _invalid();
    }
    return _repo.update(assetId, title.trim(), video.subtopicId);
  });

  Future<void> delete(String assetId) => _mutate(
    (data) => data.video(assetId) == null ? _invalid() : _repo.delete(assetId),
  );

  Future<void> moveUp(String assetId) => _move(assetId, -1);
  Future<void> moveDown(String assetId) => _move(assetId, 1);
  Future<void> _move(String assetId, int offset) async {
    final current = state;
    if (isClosed ||
        current is! TeacherVideosReady ||
        current.busy ||
        current.data.video(assetId)?.ready != true) {
      return;
    }
    final ids = current.data.movedIds(assetId, offset);
    if (ids == null) {
      return;
    }
    await _mutate((_) => _repo.reorder(_topicId!, ids));
  }

  Future<void> _mutate(
    Future<Result<void>> Function(TeacherVideosData) action,
  ) async {
    final current = state;
    final topicId = _topicId;
    if (isClosed ||
        current is! TeacherVideosReady ||
        current.busy ||
        topicId == null) {
      return;
    }
    emit(TeacherVideosReady(current.data, busy: true));
    final result = await action(current.data);
    if (isClosed) {
      return;
    }
    if (result case Failure(:final error)) {
      emit(TeacherVideosReady(current.data, error: error));
      return;
    }
    final refreshed = await _read(topicId);
    if (isClosed) {
      return;
    }
    emit(switch (refreshed) {
      Success(:final value) => TeacherVideosReady(value),
      Failure(:final error) => TeacherVideosReady(current.data, error: error),
    });
  }

  Future<Result<TeacherVideosData>> _read(String topicId) async {
    final videos = await _repo.list(topicId);
    if (isClosed) {
      return const Failure(AppError(ErrorCodes.cancelled));
    }
    if (videos case Failure(:final error)) {
      return Failure(error);
    }
    final quota = await _repo.quota();
    if (isClosed) {
      return const Failure(AppError(ErrorCodes.cancelled));
    }
    if (quota case Failure(:final error)) {
      return Failure(error);
    }
    return Success(
      TeacherVideosData(
        videos: (videos as Success<List<TeacherVideo>>).value,
        quota: (quota as Success<VideoQuota>).value,
      ),
    );
  }
}

Future<Result<void>> _invalid() =>
    Future.value(const Failure(AppError(ErrorCodes.invalidInput)));
