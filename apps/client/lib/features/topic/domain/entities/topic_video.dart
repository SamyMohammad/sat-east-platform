import 'package:equatable/equatable.dart';

import 'package:sat_east_client/core/video/video_provider.dart';

class TopicVideo extends Equatable {
  const TopicVideo({
    required this.assetId,
    required this.title,
    required this.durationS,
    required this.provider,
    required this.pct,
    required this.lastPositionS,
    this.subtopicTitle,
  });

  final String assetId;
  final String title;
  final String? subtopicTitle;
  final int durationS;
  final VideoProvider provider;
  final int pct;
  final int lastPositionS;

  @override
  List<Object?> get props => [
    assetId,
    title,
    subtopicTitle,
    durationS,
    provider,
    pct,
    lastPositionS,
  ];
}
