import 'package:equatable/equatable.dart';

class TopicNote extends Equatable {
  const TopicNote({
    required this.assetId,
    required this.title,
    this.subtopicTitle,
    this.pageCount,
  });
  final String assetId;
  final String title;
  final String? subtopicTitle;
  final int? pageCount;
  @override
  List<Object?> get props => [assetId, title, subtopicTitle, pageCount];
}
