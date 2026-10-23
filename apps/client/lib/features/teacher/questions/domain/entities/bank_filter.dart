import 'package:equatable/equatable.dart';

class BankFilter extends Equatable {
  const BankFilter({
    this.courseCode,
    this.topicId,
    this.subtopicId,
    this.status,
    this.pool,
    this.difficulty,
    this.type,
    this.q = '',
  });
  final String? courseCode;
  final String? topicId;
  final String? subtopicId;
  final String? status;
  final String? pool;
  final String? difficulty;
  final String? type;
  final String q;
  BankFilter withValue(String field, String? value) {
    final next = value == '' ? null : value;
    final values = <String, String?>{
      'courseCode': courseCode,
      'topicId': topicId,
      'subtopicId': subtopicId,
      'status': status,
      'pool': pool,
      'difficulty': difficulty,
      'type': type,
      'q': q,
      field: next,
    };
    if (field == 'courseCode') {
      values['topicId'] = null;
      values['subtopicId'] = null;
    }
    if (field == 'topicId') values['subtopicId'] = null;
    return BankFilter(
      courseCode: values['courseCode'],
      topicId: values['topicId'],
      subtopicId: values['subtopicId'],
      status: values['status'],
      pool: values['pool'],
      difficulty: values['difficulty'],
      type: values['type'],
      q: values['q'] ?? '',
    );
  }

  @override
  List<Object?> get props => [
    courseCode,
    topicId,
    subtopicId,
    status,
    pool,
    difficulty,
    type,
    q,
  ];
}
