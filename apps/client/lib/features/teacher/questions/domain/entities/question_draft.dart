import 'package:equatable/equatable.dart';

class DraftChoice extends Equatable {
  const DraftChoice({required this.label, required this.body});
  final String label;
  final String body;
  @override
  List<Object?> get props => [label, body];
}

class QuestionDraft extends Equatable {
  QuestionDraft({
    this.id,
    this.version,
    this.updatedAt,
    this.externalRef = '',
    this.stemMd = '',
    this.hintMd = '',
    this.explanationMd = '',
    this.type = 'mcq',
    this.keyChoice = 'A',
    this.tolerance = '0',
    this.topicSlug = '',
    this.subtopicSlug = '',
    this.difficulty = 'M',
    this.pool = 'practice',
    this.status = 'draft',
    this.source = '',
    this.sourcePage = '',
    this.solvedBy = '',
    this.desmosFriendly = false,
    List<String> images = const [],
    List<String> courseCodes = const [],
    List<String> skillCodes = const [],
    List<String> accepted = const [],
    List<DraftChoice> choices = defaultChoices,
    Map<String, Object?> misconceptions = const {},
  }) : images = List.unmodifiable(images),
       courseCodes = List.unmodifiable(courseCodes),
       skillCodes = List.unmodifiable(skillCodes),
       accepted = List.unmodifiable(accepted),
       choices = List.unmodifiable(choices),
       misconceptions = Map.unmodifiable(misconceptions);
  static const List<DraftChoice> defaultChoices = [
    DraftChoice(label: 'A', body: ''),
    DraftChoice(label: 'B', body: ''),
    DraftChoice(label: 'C', body: ''),
    DraftChoice(label: 'D', body: ''),
  ];
  final String? id;
  final int? version;
  final DateTime? updatedAt;
  final String externalRef;
  final String stemMd;
  final String hintMd;
  final String explanationMd;
  final String type;
  final String keyChoice;
  final String tolerance;
  final String topicSlug;
  final String subtopicSlug;
  final String difficulty;
  final String pool;
  final String status;
  final String source;
  final String sourcePage;
  final String solvedBy;
  final bool desmosFriendly;
  final List<String> images;
  final List<String> courseCodes;
  final List<String> skillCodes;
  final List<String> accepted;
  final List<DraftChoice> choices;
  final Map<String, Object?> misconceptions;
  QuestionDraft copyWith({
    String? id,
    int? version,
    DateTime? updatedAt,
    String? externalRef,
    String? stemMd,
    String? hintMd,
    String? explanationMd,
    String? type,
    String? keyChoice,
    String? tolerance,
    String? topicSlug,
    String? subtopicSlug,
    String? difficulty,
    String? pool,
    String? status,
    String? source,
    String? sourcePage,
    String? solvedBy,
    bool? desmosFriendly,
    List<String>? images,
    List<String>? courseCodes,
    List<String>? skillCodes,
    List<String>? accepted,
    List<DraftChoice>? choices,
    Map<String, Object?>? misconceptions,
  }) => QuestionDraft(
    id: id ?? this.id,
    version: version ?? this.version,
    updatedAt: updatedAt ?? this.updatedAt,
    externalRef: externalRef ?? this.externalRef,
    stemMd: stemMd ?? this.stemMd,
    hintMd: hintMd ?? this.hintMd,
    explanationMd: explanationMd ?? this.explanationMd,
    type: type ?? this.type,
    keyChoice: keyChoice ?? this.keyChoice,
    tolerance: tolerance ?? this.tolerance,
    topicSlug: topicSlug ?? this.topicSlug,
    subtopicSlug: subtopicSlug ?? this.subtopicSlug,
    difficulty: difficulty ?? this.difficulty,
    pool: pool ?? this.pool,
    status: status ?? this.status,
    source: source ?? this.source,
    sourcePage: sourcePage ?? this.sourcePage,
    solvedBy: solvedBy ?? this.solvedBy,
    desmosFriendly: desmosFriendly ?? this.desmosFriendly,
    images: images ?? this.images,
    courseCodes: courseCodes ?? this.courseCodes,
    skillCodes: skillCodes ?? this.skillCodes,
    accepted: accepted ?? this.accepted,
    choices: choices ?? this.choices,
    misconceptions: misconceptions ?? this.misconceptions,
  );
  @override
  List<Object?> get props => [
    id,
    version,
    updatedAt,
    externalRef,
    stemMd,
    hintMd,
    explanationMd,
    type,
    keyChoice,
    tolerance,
    topicSlug,
    subtopicSlug,
    difficulty,
    pool,
    status,
    source,
    sourcePage,
    solvedBy,
    desmosFriendly,
    images,
    courseCodes,
    skillCodes,
    accepted,
    choices,
    misconceptions,
  ];
}
