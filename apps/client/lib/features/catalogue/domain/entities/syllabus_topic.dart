import 'package:equatable/equatable.dart';

class SyllabusTopic extends Equatable {
  const SyllabusTopic({
    required this.slug,
    required this.title,
    required this.isFreePreview,
    required this.subtopicCount,
  });

  final String slug;
  final String title;
  final bool isFreePreview;
  final int subtopicCount;

  @override
  List<Object?> get props => [slug, title, isFreePreview, subtopicCount];
}
