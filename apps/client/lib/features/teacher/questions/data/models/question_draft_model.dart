import 'package:sat_east_client/features/teacher/questions/domain/entities/import_report.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/question_draft.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/question_save_result.dart';

QuestionDraft questionDraftFromJson(Object? raw) {
  final json = _object(raw);
  final key = _object(json['key']);
  final type = _string(json['type']);
  final misconceptions = json['misconceptions'] == null
      ? <String, Object?>{}
      : _object(json['misconceptions']);
  final choices = _array(json['choices']).map((raw) {
    final choice = _object(raw);
    return DraftChoice(
      label: _string(choice['label']),
      body: _string(choice['body_md']),
    );
  }).toList();
  final updated = DateTime.tryParse(_string(json['updated_at']));
  if (updated == null) throw const FormatException('timestamp');
  if (json['desmos_friendly'] is! bool) throw const FormatException('boolean');
  return QuestionDraft(
    id: _string(json['id']),
    version: _integer(json['version']),
    updatedAt: updated,
    externalRef: _optional(json['external_ref']),
    stemMd: _string(json['stem_md']),
    hintMd: _optional(json['hint_md']),
    explanationMd: _optional(json['explanation_md']),
    type: type,
    keyChoice: type == 'mcq' ? _string(key['choice']) : '',
    accepted: type == 'spr' ? _strings(key['accepted']) : const [],
    tolerance: type == 'spr' && key.containsKey('tolerance')
        ? _numberText(key['tolerance'])
        : '0',
    images: _strings(json['images']),
    courseCodes: _strings(json['course_codes']),
    skillCodes: _strings(json['skill_codes']),
    choices: choices,
    misconceptions: misconceptions,
    topicSlug: _string(json['topic_slug']),
    subtopicSlug: _string(json['subtopic_slug']),
    difficulty: _string(json['difficulty']),
    pool: _string(json['pool']),
    status: _string(json['status']),
    desmosFriendly: json['desmos_friendly']! as bool,
    source: _optional(json['source']),
    sourcePage: json['source_page'] == null
        ? ''
        : _numberText(json['source_page']),
    solvedBy: _optional(json['solved_by']),
  );
}

Map<String, Object?> questionDraftToJson(QuestionDraft d) => {
  'external_ref': d.externalRef,
  'course_codes': d.courseCodes,
  'topic_slug': d.topicSlug,
  'subtopic_slug': d.subtopicSlug,
  'skill_codes': d.skillCodes.map((v) => v.trim()).toList(),
  'type': d.type,
  'difficulty': d.difficulty,
  'stem_md': d.stemMd,
  'images': d.images,
  'choices': d.type == 'mcq'
      ? [
          for (final c in d.choices) {'label': c.label, 'body_md': c.body},
        ]
      : <Object?>[],
  'key': d.type == 'mcq'
      ? {'choice': d.keyChoice}
      : {
          'accepted': d.accepted,
          if (d.tolerance.isNotEmpty) 'tolerance': _jsonNumber(d.tolerance),
        },
  'explanation_md': d.explanationMd.isEmpty ? null : d.explanationMd,
  'hint_md': d.hintMd.isEmpty ? null : d.hintMd,
  'misconceptions': d.misconceptions,
  'desmos_friendly': d.desmosFriendly,
  'pool': d.pool,
  'status': d.status,
  'source': d.source.isEmpty ? null : d.source,
  'source_page': d.sourcePage.isEmpty ? null : _jsonNumber(d.sourcePage),
  'solved_by': d.solvedBy.isEmpty ? null : d.solvedBy,
};
QuestionSaveResult questionSaveResultFromJson(Object? raw) {
  final json = _object(raw);
  if (json['ok'] == false) {
    final errors = _array(json['errors']).map((raw) {
      final e = _object(raw);
      return ImportProblem(
        row: _integer(e['row']),
        externalRef: e['external_ref'] == null
            ? null
            : _string(e['external_ref']),
        field: _string(e['field']),
        problem: _string(e['problem']),
      );
    }).toList();
    if (errors.isEmpty) throw const FormatException('empty rejection');
    return QuestionRejected(errors);
  }
  return QuestionSaved(
    id: _string(json['id']),
    version: _integer(json['version']),
  );
}

Map<String, Object?> _object(Object? v) {
  if (v is! Map<String, Object?>) throw const FormatException('object');
  return v;
}

List<Object?> _array(Object? v) {
  if (v is! List<Object?>) throw const FormatException('array');
  return v;
}

String _string(Object? v) {
  if (v is! String) throw const FormatException('string');
  return v;
}

String _optional(Object? v) => v == null ? '' : _string(v);
List<String> _strings(Object? v) => _array(v).map(_string).toList();
int _integer(Object? v) {
  if (v is! int || v < 1) throw const FormatException('version/index');
  return v;
}

String _numberText(Object? v) {
  if (v is! num || !v.isFinite) throw const FormatException('number');
  return v.toString();
}

Object _jsonNumber(String text) {
  final number = num.tryParse(text);
  return number != null && number.isFinite ? number : text;
}
