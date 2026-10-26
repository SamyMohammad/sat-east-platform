import 'package:equatable/equatable.dart';
import 'package:sat_east_client/core/video/video_provider.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/video_quota.dart';

class TeacherVideo extends Equatable {
  const TeacherVideo({
    required this.assetId,
    required this.title,
    required this.durationS,
    required this.provider,
    required this.ready,
    required this.sort,
    this.subtopicId,
    this.subtopicTitle,
    this.sizeMb,
    this.youtubeId,
  });

  final String assetId;
  final String title;
  final String? subtopicId;
  final String? subtopicTitle;
  final int durationS;
  final int? sizeMb;
  final VideoProvider provider;
  final String? youtubeId;
  final bool ready;
  final int sort;

  static bool validTitle(String title) =>
      title.trim().isNotEmpty && title.trim().length <= 120;

  @override
  List<Object?> get props => [
    assetId,
    title,
    subtopicId,
    subtopicTitle,
    durationS,
    sizeMb,
    provider,
    youtubeId,
    ready,
    sort,
  ];
}

class TeacherVideosData extends Equatable {
  TeacherVideosData({required List<TeacherVideo> videos, required this.quota})
    : videos = List.unmodifiable(videos);

  final List<TeacherVideo> videos;
  final VideoQuota quota;

  TeacherVideo? video(String id) =>
      videos.where((video) => video.assetId == id).firstOrNull;

  List<String>? movedIds(String id, int offset) {
    final ids = videos.map((video) => video.assetId).toList();
    final index = ids.indexOf(id);
    final target = index + offset;
    if (index < 0 || target < 0 || target >= ids.length || offset.abs() != 1) {
      return null;
    }
    ids.insert(target, ids.removeAt(index));
    return ids;
  }

  @override
  List<Object?> get props => [videos, quota];
}
