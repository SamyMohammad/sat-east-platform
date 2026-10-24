import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/questions/data/models/question_draft_model.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/question_draft.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/question_save_result.dart';
import 'package:sat_east_client/features/teacher/questions/domain/repositories/question_editor_repository.dart';

const Map<String, Object?> editorJson = {
  'id': 'q1',
  'version': 2,
  'updated_at': '2026-10-24T12:00:00Z',
  'external_ref': 'EDIT_1',
  'course_codes': <String>['SAT'],
  'topic_slug': 'linear',
  'subtopic_slug': 'one-step',
  'skill_codes': <String>['ALG.LIN'],
  'type': 'mcq',
  'difficulty': 'M',
  'stem_md': 'Solve x.',
  'images': <String>[],
  'choices': <Object?>[
    {'label': 'A', 'body_md': '1'},
    {'label': 'B', 'body_md': '2'},
  ],
  'key': {'choice': 'B'},
  'explanation_md': 'Two.',
  'hint_md': 'Think.',
  'misconceptions': {'A': 'Used one.'},
  'desmos_friendly': false,
  'pool': 'practice',
  'status': 'draft',
  'source': 'teacher.pdf',
  'source_page': 7,
  'solved_by': 'teacher',
};
final QuestionDraft editorDraft = questionDraftFromJson(editorJson);

class FakeEditorRepository implements QuestionEditorRepository {
  Result<QuestionDraft> getResult = Success(editorDraft);
  Result<QuestionSaveResult> saveResult = const Success(
    QuestionSaved(id: 'q1', version: 3),
  );
  Future<Result<QuestionDraft>>? pendingGet;
  Future<Result<QuestionSaveResult>>? pendingSave;
  void Function()? onGet;
  final List<String> gets = [];
  final List<QuestionDraft> saves = [];
  @override
  Future<Result<QuestionDraft>> get(String id) {
    gets.add(id);
    onGet?.call();
    return pendingGet ?? Future.value(getResult);
  }

  @override
  Future<Result<QuestionSaveResult>> save(QuestionDraft draft) {
    saves.add(draft);
    return pendingSave ?? Future.value(saveResult);
  }
}
