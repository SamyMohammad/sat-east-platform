import 'package:equatable/equatable.dart';

class BankRow extends Equatable {
  const BankRow({
    required this.id,
    required this.externalRef,
    required this.stemPreview,
    required this.type,
    required this.topicTitle,
    required this.subtopicTitle,
    required this.difficulty,
    required this.pool,
    required this.status,
    required this.version,
    required this.updatedAt,
  });
  final String id;
  final String? externalRef;
  final String stemPreview;
  final String type;
  final String topicTitle;
  final String subtopicTitle;
  final String difficulty;
  final String pool;
  final String status;
  final int version;
  final DateTime updatedAt;
  @override
  List<Object?> get props => [
    id,
    externalRef,
    stemPreview,
    type,
    topicTitle,
    subtopicTitle,
    difficulty,
    pool,
    status,
    version,
    updatedAt,
  ];
}
