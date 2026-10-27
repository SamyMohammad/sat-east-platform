import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/question_draft.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/question_save_result.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/topic_option.dart';
import 'package:sat_east_client/features/teacher/questions/domain/repositories/question_bank_repository.dart';
import 'package:sat_east_client/features/teacher/questions/domain/repositories/question_editor_repository.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_editor_state.dart';

class QuestionEditorCubit extends Cubit<QuestionEditorState> {
  QuestionEditorCubit(this._repository, this._bank)
    : super(QuestionEditorState(loading: true));
  final QuestionEditorRepository _repository;
  final QuestionBankRepository _bank;
  var _generation = 0;
  Future<void> load([String? id]) async {
    if (isClosed || state.saving) return;
    final generation = ++_generation;
    emit(QuestionEditorState(loading: true));
    final topics = await _bank.topics();
    if (isClosed || generation != _generation) return;
    if (topics case Failure(:final error)) {
      emit(QuestionEditorState(error: error));
      return;
    }
    final options = (topics as Success<List<BankCourse>>).value;
    final result = id == null
        ? Success(QuestionDraft())
        : await _repository.get(id);
    if (isClosed || generation != _generation) return;
    switch (result) {
      case Success(:final value):
        emit(
          QuestionEditorState(draft: value, original: value, topics: options),
        );
      case Failure(:final error):
        emit(QuestionEditorState(topics: options, error: error));
    }
  }

  bool get _canEdit =>
      !isClosed && !state.loading && !state.saving && state.draft != null;
  void _edit(QuestionDraft next, Set<String> fields) {
    if (!_canEdit) return;
    emit(
      QuestionEditorState(
        draft: next,
        original: state.original,
        topics: state.topics,
        conflict: state.conflict,
        serverErrors: {
          for (final e in state.serverErrors.entries)
            if (!fields.contains(e.key)) e.key: e.value,
        },
      ),
    );
  }

  void editContent({
    String? stemMd,
    String? hintMd,
    String? explanationMd,
    List<String>? images,
  }) {
    if (!_canEdit) return;
    _edit(
      state.draft!.copyWith(
        stemMd: stemMd,
        hintMd: hintMd,
        explanationMd: explanationMd,
        images: images,
      ),
      {
        if (stemMd != null) 'stem_md',
        if (hintMd != null) 'hint_md',
        if (explanationMd != null) 'explanation_md',
        if (images != null) 'images',
      },
    );
  }

  void editAnswer({
    String? type,
    List<DraftChoice>? choices,
    String? keyChoice,
    List<String>? accepted,
    String? tolerance,
    Map<String, Object?>? misconceptions,
  }) {
    if (!_canEdit) return;
    final current = state.draft!;
    _edit(
      current.copyWith(
        type: type,
        choices:
            choices ??
            (type == 'mcq' && current.choices.isEmpty
                ? QuestionDraft.defaultChoices
                : null),
        keyChoice: keyChoice,
        accepted: accepted,
        tolerance: tolerance,
        misconceptions: misconceptions,
      ),
      {'type', 'choices', 'key', 'misconceptions'},
    );
  }

  void editChoice(String label, {String? body, String? misconception}) {
    if (!_canEdit) return;
    final current = state.draft!;
    editAnswer(
      choices: [
        for (final c in current.choices)
          if (c.label == label)
            DraftChoice(label: label, body: body ?? c.body)
          else
            c,
      ],
      misconceptions: misconception == null
          ? null
          : {...current.misconceptions, label: misconception},
    );
  }

  void editClassification({
    List<String>? courseCodes,
    String? topicSlug,
    String? subtopicSlug,
    List<String>? skillCodes,
    String? difficulty,
    String? pool,
    bool? desmosFriendly,
    String? status,
  }) {
    if (!_canEdit) return;
    final current = state.draft!;
    final courseChanged =
        courseCodes != null &&
        courseCodes.firstOrNull != current.courseCodes.firstOrNull;
    _edit(
      current.copyWith(
        courseCodes: courseCodes,
        topicSlug: topicSlug ?? (courseChanged ? '' : null),
        subtopicSlug:
            subtopicSlug ??
            (courseChanged ||
                    topicSlug != null && topicSlug != current.topicSlug
                ? ''
                : null),
        skillCodes: skillCodes,
        difficulty: difficulty,
        pool: pool,
        desmosFriendly: desmosFriendly,
        status: status,
      ),
      {
        'course_codes',
        'topic_slug',
        'subtopic_slug',
        'skill_codes',
        'difficulty',
        'pool',
        'status',
        'desmos_friendly',
      },
    );
  }

  void editSource({
    String? externalRef,
    String? source,
    String? sourcePage,
    String? solvedBy,
  }) {
    if (!_canEdit) return;
    _edit(
      state.draft!.copyWith(
        externalRef: externalRef,
        source: source,
        sourcePage: sourcePage,
        solvedBy: solvedBy,
      ),
      {
        if (externalRef != null) 'external_ref',
        if (source != null) 'source',
        if (sourcePage != null) 'source_page',
        if (solvedBy != null) 'solved_by',
      },
    );
  }

  void discard() {
    if (!_canEdit) return;
    emit(
      QuestionEditorState(
        draft: state.original,
        original: state.original,
        topics: state.topics,
        conflict: state.conflict,
      ),
    );
  }

  Future<void> save() async {
    if (!_canEdit || !state.isDirty || state.conflict) return;
    final current = state;
    final draft = current.draft!;
    final generation = ++_generation;
    emit(
      QuestionEditorState(
        draft: draft,
        original: current.original,
        topics: current.topics,
        saving: true,
      ),
    );
    final result = await _repository.save(draft);
    if (isClosed || generation != _generation) return;
    switch (result) {
      case Failure(:final error):
        emit(
          QuestionEditorState(
            draft: draft,
            original: current.original,
            topics: current.topics,
            error: error.code == ErrorCodes.versionConflict ? null : error,
            conflict: error.code == ErrorCodes.versionConflict,
          ),
        );
      case Success(:final value):
        switch (value) {
          case QuestionSaved(:final id, :final version):
            final saved = draft.copyWith(id: id, version: version);
            emit(
              QuestionEditorState(
                draft: saved,
                original: saved,
                topics: current.topics,
              ),
            );
          case QuestionRejected(:final errors):
            final fields = <String, List<String>>{};
            for (final error in errors) {
              fields.putIfAbsent(error.field, () => []).add(error.problem);
            }
            emit(
              QuestionEditorState(
                draft: draft,
                original: current.original,
                topics: current.topics,
                serverErrors: fields,
              ),
            );
        }
    }
  }

  @override
  Future<void> close() {
    _generation++;
    return super.close();
  }
}
