import 'package:equatable/equatable.dart';

enum ReviewSection {
  reported('reported'),
  needsReview('needs_review');

  const ReviewSection(this.value);
  final String value;
}

class ReviewRow extends Equatable {
  ReviewRow({
    required this.questionId,
    required this.externalRef,
    required this.stemPreview,
    required this.status,
    required this.openCount,
    required Map<String, int> reasons,
    required this.oldestReportAt,
    required this.latestNote,
  }) : reasons = Map.unmodifiable(reasons);
  final String questionId;
  final String? externalRef;
  final String stemPreview;
  final String status;
  final int openCount;
  final Map<String, int> reasons;
  final DateTime? oldestReportAt;
  final String? latestNote;
  @override
  bool get stringify => false;
  @override
  List<Object?> get props => [
    questionId,
    externalRef,
    stemPreview,
    status,
    openCount,
    reasons,
    oldestReportAt,
    latestNote,
  ];
}

class ReviewPage extends Equatable {
  ReviewPage({
    required this.total,
    required this.page,
    required this.pageSize,
    required List<ReviewRow> rows,
  }) : rows = List.unmodifiable(rows);
  final int total;
  final int page;
  final int pageSize;
  final List<ReviewRow> rows;
  bool get hasNext => page * pageSize < total;
  bool get hasPrevious => page > 1;
  @override
  bool get stringify => false;
  @override
  List<Object?> get props => [total, page, pageSize, rows];
}

class QuestionReport extends Equatable {
  const QuestionReport({
    required this.id,
    required this.reason,
    required this.note,
    required this.createdAt,
    required this.fullName,
  });
  final String id;
  final String reason;
  final String? note;
  final DateTime createdAt;
  final String fullName;
  @override
  bool get stringify => false;
  @override
  List<Object?> get props => [id, reason, note, createdAt, fullName];
}

class ReviewCounts extends Equatable {
  const ReviewCounts({required this.reported, required this.needsReview});
  final int reported;
  final int needsReview;
  int get total => reported + needsReview;
  @override
  List<Object?> get props => [reported, needsReview];
}
