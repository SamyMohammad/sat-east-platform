import 'package:flutter/material.dart';

import 'package:sat_east_client/core/grading/spr_editing.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/shared/widgets/spr_input.dart';
import 'package:sat_east_client/shared/widgets/spr_keypad.dart';

/// SPR field plus the phone keypad. The parent owns [text]; this widget keeps
/// only the keypad visibility and the last ignored-key hint.
class SprAnswerArea extends StatefulWidget {
  const SprAnswerArea({
    required this.text,
    required this.state,
    required this.useKeypad,
    super.key,
    this.correctAnswer,
    this.onChanged,
  });

  final String text;
  final SprInputState state;
  final bool useKeypad;

  /// Shown only while [state] is [SprInputState.incorrect].
  final String? correctAnswer;
  final ValueChanged<String>? onChanged;

  @override
  State<SprAnswerArea> createState() => _SprAnswerAreaState();
}

class _SprAnswerAreaState extends State<SprAnswerArea> {
  bool _keypadVisible = true;
  SprKeyHint? _keyHint;

  void _showKeypad() {
    if (!_keypadVisible) setState(() => _keypadVisible = true);
  }

  void _onTyped(String value) {
    setState(() => _keyHint = null);
    widget.onChanged?.call(value);
  }

  void _onKey(SprKey key) {
    final edit = applySprKey(widget.text, key);
    setState(() => _keyHint = edit.hint);
    if (edit.text != widget.text) widget.onChanged?.call(edit.text);
  }

  @override
  Widget build(BuildContext context) {
    final showKeypad =
        widget.useKeypad &&
        _keypadVisible &&
        widget.state == SprInputState.editable;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpace.s3,
      children: [
        // A raw pointer listener never loses the gesture arena to the field.
        Listener(
          onPointerDown: (_) => _showKeypad(),
          child: SprInput(
            value: widget.text,
            onChanged: _onTyped,
            state: widget.state,
            keyHint: _keyHint,
            correctAnswer: widget.state == SprInputState.incorrect
                ? widget.correctAnswer
                : null,
            useKeypad: widget.useKeypad,
          ),
        ),
        if (showKeypad)
          SprKeypad(
            onKey: _onKey,
            onHide: () => setState(() => _keypadVisible = false),
          ),
      ],
    );
  }
}
