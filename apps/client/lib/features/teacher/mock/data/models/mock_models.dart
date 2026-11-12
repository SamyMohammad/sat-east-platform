import 'package:sat_east_client/features/teacher/mock/domain/entities/mock_entities.dart';

MockOverview mockOverviewFromJson(Object? raw) {
  final json = _object(raw);
  final template = _object(json['template']);
  final next = _object(json['next_form']);
  return MockOverview(
    templateName: _text(template['name']),
    needPerForm: _array(json['need_per_form']).map((raw) {
      final cell = _object(raw);
      return MockCell(
        domain: _text(cell['domain']),
        difficulty: _text(cell['difficulty']),
        type: _text(cell['type']),
        count: _count(cell['count']),
      );
    }).toList(),
    forms: _array(json['forms']).map((raw) {
      final form = _object(raw);
      return MockFormSummary(
        setNo: _count(form['set_no'], min: 1),
        formNo: _count(form['form_no'], min: 1),
        status: _status(form['status']),
        publishedAt: _optionalDate(form['published_at']),
      );
    }).toList(),
    missing: _shortageCells(next['missing']),
    noDomain: _count(next['no_domain']),
  );
}

AssembleResult assembleResultFromJson(Object? raw) {
  final json = _object(raw);
  return switch (json['ok']) {
    true => Assembled(
      setNo: _count(json['set_no'], min: 1),
      formNo: _count(json['form_no'], min: 1),
    ),
    false => Shortage(
      missing: _shortageCells(json['missing']),
      noDomain: _count(json['no_domain']),
    ),
    _ => throw const FormatException('ok'),
  };
}

MockForm mockFormFromJson(Object? raw) {
  final json = _object(raw);
  return MockForm(
    setNo: _count(json['set_no'], min: 1),
    formNo: _count(json['form_no'], min: 1),
    status: _status(json['status']),
    publishedAt: _optionalDate(json['published_at']),
    modules: _array(json['modules']).map((raw) {
      final module = _object(raw);
      return MockModule(
        name: _text(module['module']),
        slots: _array(module['questions']).map((raw) {
          final q = _object(raw);
          return MockSlot(
            slotNo: _count(q['slot_no'], min: 1),
            questionId: _text(q['id']),
            externalRef: _optionalText(q['external_ref']),
            type: _text(q['type']),
            difficulty: _text(q['difficulty']),
            domain: _optionalText(q['domain']),
            stemMd: _text(q['stem_md']),
          );
        }).toList(),
      );
    }).toList(),
  );
}

List<MockCandidate> mockCandidatesFromJson(Object? raw) =>
    _array(raw).map((raw) {
      final c = _object(raw);
      return MockCandidate(
        id: _text(c['id']),
        externalRef: _optionalText(c['external_ref']),
        stemMd: _text(c['stem_md']),
      );
    }).toList();

/// Mutations that answer `{ok:true}`.
void mockOkFromJson(Object? raw) {
  if (_object(raw)['ok'] != true) throw const FormatException('ok');
}

PublishResult publishResultFromJson(Object? raw) {
  final json = _object(raw);
  return switch (json['ok']) {
    true => const Published(),
    false => Stale(_array(json['stale']).map(_text).toList()),
    _ => throw const FormatException('ok'),
  };
}

List<MockShortageCell> _shortageCells(Object? raw) => _array(raw).map((raw) {
  final cell = _object(raw);
  final modules = _object(cell['modules']);
  return MockShortageCell(
    domain: _text(cell['domain']),
    difficulty: _text(cell['difficulty']),
    type: _text(cell['type']),
    needed: _count(cell['needed']),
    available: _count(cell['available']),
    modules: {for (final e in modules.entries) e.key: _count(e.value)},
  );
}).toList();

MockFormStatus _status(Object? raw) => switch (_text(raw)) {
  'draft' => MockFormStatus.draft,
  'published' => MockFormStatus.published,
  _ => throw const FormatException('status'),
};

Map<String, Object?> _object(Object? raw) {
  if (raw is! Map<String, Object?>) throw const FormatException('object');
  return raw;
}

List<Object?> _array(Object? raw) {
  if (raw is! List<Object?>) throw const FormatException('array');
  return raw;
}

String _text(Object? raw) {
  if (raw is! String) throw const FormatException('text');
  return raw;
}

String? _optionalText(Object? raw) => raw == null ? null : _text(raw);

DateTime? _optionalDate(Object? raw) {
  if (raw == null) return null;
  final date = DateTime.tryParse(_text(raw));
  if (date == null) throw const FormatException('date');
  return date;
}

int _count(Object? raw, {int min = 0}) {
  if (raw is! int || raw < min) throw const FormatException('count');
  return raw;
}
