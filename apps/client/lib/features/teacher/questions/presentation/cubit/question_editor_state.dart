import 'package:equatable/equatable.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/question_draft.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/topic_option.dart';

class QuestionEditorState extends Equatable {
  QuestionEditorState({
    this.draft,
    this.original,
    this.topics = const [],
    this.loading = false,
    this.saving = false,
    this.conflict = false,
    this.error,
    Map<String, List<String>> serverErrors = const {},
  }) : serverErrors = serverErrors.isEmpty
           ? const {}
           : Map.unmodifiable(
               serverErrors.map(
                 (k, v) => MapEntry(k, List<String>.unmodifiable(v)),
               ),
             );
  final QuestionDraft? draft;
  final QuestionDraft? original;
  final List<BankCourse> topics;
  final bool loading;
  final bool saving;
  final bool conflict;
  final AppError? error;
  final Map<String, List<String>> serverErrors;
  bool get isDirty => draft != null && draft != original;
  @override
  List<Object?> get props => [
    draft,
    original,
    topics,
    loading,
    saving,
    conflict,
    error,
    serverErrors,
  ];
}
