import 'package:equatable/equatable.dart';

/// One blueprint cell of a form: how many questions of this kind it needs.
class MockCell extends Equatable {
  const MockCell({
    required this.domain,
    required this.difficulty,
    required this.type,
    required this.count,
  });
  final String domain;
  final String difficulty;
  final String type;
  final int count;
  @override
  List<Object?> get props => [domain, difficulty, type, count];
}

/// A cell the reserve bank cannot fill; [modules] maps module name to need.
class MockShortageCell extends Equatable {
  const MockShortageCell({
    required this.domain,
    required this.difficulty,
    required this.type,
    required this.needed,
    required this.available,
    required this.modules,
  });
  final String domain;
  final String difficulty;
  final String type;
  final int needed;
  final int available;
  final Map<String, int> modules;
  @override
  List<Object?> get props => [
    domain,
    difficulty,
    type,
    needed,
    available,
    modules,
  ];
}

enum MockFormStatus { draft, published }

class MockFormSummary extends Equatable {
  const MockFormSummary({
    required this.setNo,
    required this.formNo,
    required this.status,
    this.publishedAt,
  });
  final int setNo;
  final int formNo;
  final MockFormStatus status;
  final DateTime? publishedAt;
  @override
  List<Object?> get props => [setNo, formNo, status, publishedAt];
}

class MockOverview extends Equatable {
  const MockOverview({
    required this.templateName,
    required this.needPerForm,
    required this.forms,
    required this.missing,
    required this.noDomain,
  });
  final String templateName;
  final List<MockCell> needPerForm;
  final List<MockFormSummary> forms;
  final List<MockShortageCell> missing;

  /// Mock questions without exactly one blueprint domain.
  final int noDomain;

  bool get canAssemble => missing.isEmpty;
  @override
  List<Object?> get props => [
    templateName,
    needPerForm,
    forms,
    missing,
    noDomain,
  ];
}

class MockSlot extends Equatable {
  const MockSlot({
    required this.slotNo,
    required this.questionId,
    required this.externalRef,
    required this.type,
    required this.difficulty,
    required this.domain,
    required this.stemMd,
  });
  final int slotNo;
  final String questionId;
  final String? externalRef;
  final String type;
  final String difficulty;

  /// Null when the question lost its skill since assembly (a stale slot).
  final String? domain;
  final String stemMd;
  @override
  List<Object?> get props => [
    slotNo,
    questionId,
    externalRef,
    type,
    difficulty,
    domain,
    stemMd,
  ];
}

class MockModule extends Equatable {
  const MockModule({required this.name, required this.slots});
  final String name;
  final List<MockSlot> slots;
  @override
  List<Object?> get props => [name, slots];
}

class MockForm extends Equatable {
  const MockForm({
    required this.setNo,
    required this.formNo,
    required this.status,
    required this.modules,
    this.publishedAt,
  });
  final int setNo;
  final int formNo;
  final MockFormStatus status;
  final DateTime? publishedAt;
  final List<MockModule> modules;
  @override
  List<Object?> get props => [setNo, formNo, status, publishedAt, modules];
}

class MockCandidate extends Equatable {
  const MockCandidate({
    required this.id,
    required this.externalRef,
    required this.stemMd,
  });
  final String id;
  final String? externalRef;
  final String stemMd;
  @override
  List<Object?> get props => [id, externalRef, stemMd];
}

/// Assembling either builds a draft form or reports a bank shortage.
sealed class AssembleResult extends Equatable {
  const AssembleResult();
}

final class Assembled extends AssembleResult {
  const Assembled({required this.setNo, required this.formNo});
  final int setNo;
  final int formNo;
  @override
  List<Object?> get props => [setNo, formNo];
}

final class Shortage extends AssembleResult {
  const Shortage({required this.missing, required this.noDomain});
  final List<MockShortageCell> missing;
  final int noDomain;
  @override
  List<Object?> get props => [missing, noDomain];
}

/// Publishing either succeeds or lists the questions that went stale.
sealed class PublishResult extends Equatable {
  const PublishResult();
}

final class Published extends PublishResult {
  const Published();
  @override
  List<Object?> get props => const [];
}

final class Stale extends PublishResult {
  const Stale(this.questionIds);
  final List<String> questionIds;
  @override
  List<Object?> get props => [questionIds];
}
