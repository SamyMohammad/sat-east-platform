import 'package:flutter/foundation.dart';

/// The student's working state for one question.
@immutable
final class AnswerState {
  const AnswerState({
    this.selected,
    this.eliminated = const {},
    this.marked = false,
    this.sprText = '',
  });

  final String? selected;
  final Set<String> eliminated;
  final bool marked;
  final String sprText;

  bool get hasAnswer => selected != null || sprText.trim().isNotEmpty;
}
