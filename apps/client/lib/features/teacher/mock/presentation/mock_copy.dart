import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/features/teacher/mock/domain/entities/mock_entities.dart';

const mockOverviewTitle = 'SAT mock exams';
const mockReadyLine = 'Ready to assemble a form';
const mockShortLine = 'Not enough questions to assemble a form';
const mockNeedTitle = 'What one form needs';
const mockShortageBanner =
    'No form was created. The reserve bank is short on questions.';
const mockFormsTitle = 'Forms';
const mockNoFormsTitle = 'No forms yet';
const mockNoFormsMessage = 'Assemble the first form from the reserve bank.';
const mockNoCourseTitle = 'No SAT course yet';
const mockNoCourseMessage =
    'Mock exams are built from the SAT course. Create it in the course '
    'builder first.';
const mockAssembleLabel = 'Assemble form';
const mockAssembleTitle = 'Assemble a form';
const mockAssembleConfirm = 'Assemble';
const mockCancel = 'Cancel';
const mockSetLabel = 'Set';

String mockErrorCopy(String code) => switch (code) {
  ErrorCodes.forbidden => 'Only teachers can manage mock exams.',
  ErrorCodes.invalidInput => 'This form no longer exists. Refresh the page.',
  ErrorCodes.mockFormPublished => 'This form is already published.',
  ErrorCodes.network => 'No connection. Check your network and try again.',
  _ => 'Something went wrong. Try again.',
};

String mockNoDomainLine(int n) => n == 1
    ? '1 mock question has no single SAT domain'
    : '$n mock questions have no single SAT domain';

String mockSetOption(int setNo) => 'Set $setNo';
String mockNextSetOption(int setNo) => 'Next set ($setNo)';
String mockFormTitle(int setNo, int formNo) => 'Set $setNo · Form $formNo';
String mockStatusLabel(MockFormStatus status) => switch (status) {
  MockFormStatus.draft => 'Draft',
  MockFormStatus.published => 'Published',
};
String mockPerFormTotal(int n) => '$n questions per form';

/// "advanced_math" -> "Advanced math".
String mockHumanize(String slug) {
  final text = slug.replaceAll('_', ' ');
  return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}

String mockCellLabel(String domain, String difficulty, String type) =>
    '${mockHumanize(domain)} · ${mockHumanize(difficulty)} · '
    '${type.toUpperCase()}';

String mockShortageLine(MockShortageCell cell) {
  final modules = cell.modules.entries
      .map((e) => '${e.key} ${e.value}')
      .join(', ');
  final base =
      '${mockCellLabel(cell.domain, cell.difficulty, cell.type)}: '
      'need ${cell.needed}, have ${cell.available}';
  return modules.isEmpty ? base : '$base ($modules)';
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "10 Nov 2026" (UTC date, so it does not depend on the device zone).
String mockDateLabel(DateTime at) {
  final utc = at.toUtc();
  return '${utc.day} ${_months[utc.month - 1]} ${utc.year}';
}

String mockPublishedLine(DateTime at) => 'Published ${mockDateLabel(at)}';

const mockFormMissingTitle = 'This form no longer exists';
const mockFormMissingMessage =
    'It may have been deleted. Go back to the forms list.';
const mockBackToList = 'Back to mock exams';
const mockAllForms = 'All forms';
const mockNoDomain = 'No domain';
const mockNoReference = 'No reference';
const mockStaleMarker = 'Changed since assembly';
const mockPublishedReadOnly = 'This form is published and read-only.';
const mockSwapTooltip = 'Swap question';
const mockSwapTitle = 'Swap question';
const mockNoCandidates = 'No other question fits this slot';
const mockPublishLabel = 'Publish';
const mockDeleteLabel = 'Delete draft';
const mockPreviewTitle = 'Question preview';
const mockClosePreview = 'Close preview';

String mockModuleTitle(String name) => switch (name) {
  'M1' => 'Module 1',
  'M2E' => 'Module 2 (easier)',
  'M2H' => 'Module 2 (harder)',
  _ => name,
};

String mockStaleBanner(int n) => n == 1
    ? '1 question changed since assembly. Swap it, then publish again.'
    : '$n questions changed since assembly. Swap them, then publish again.';

String mockSlotLabel(int slotNo) => 'Slot $slotNo';

String mockSlotDetail(MockSlot slot) =>
    '${slot.domain == null ? mockNoDomain : mockHumanize(slot.domain!)} · '
    '${mockHumanize(slot.difficulty)} · ${slot.type.toUpperCase()}';

String mockStemLine(String stemMd) => stemMd
    .split('\n')
    .map((l) => l.trim())
    .firstWhere((l) => l.isNotEmpty, orElse: () => '');

const mockDeleteTitle = 'Delete draft';
String mockDeleteBody(int setNo, int formNo) =>
    'Delete ${mockFormTitle(setNo, formNo)}? Its questions become available '
    "again. This can't be undone.";
const mockPublishTitle = 'Publish form';
String mockPublishBody(int setNo, int formNo) =>
    'Publish ${mockFormTitle(setNo, formNo)}? '
    "A published form can't be edited or unpublished.";
const mockSwapConfirmTitle = 'Swap question';
String mockSwapConfirmBody(String oldRef, String newRef) =>
    'Replace $oldRef with $newRef in this slot?';
const mockSwapConfirmLabel = 'Swap';
