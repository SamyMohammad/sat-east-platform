import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sat_east_client/core/grading/spr_answer.dart';
import 'package:sat_east_client/core/grading/spr_editing.dart';
import 'package:sat_east_client/core/math_render/math_text.dart';
import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/shared/widgets/feedback_label.dart';

part 'spr_input_feedback.dart';
part 'spr_input_format.dart';

enum SprInputState { editable, disabled, correct, incorrect }

/// Student-produced response field with live Answer Preview (§3). Controlled:
/// the parent owns [value].
class SprInput extends StatefulWidget {
  const SprInput({
    required this.value,
    required this.onChanged,
    super.key,
    this.state = SprInputState.editable,
    this.keyHint,
    this.correctAnswer,
    this.useKeypad = false,
    this.focusNode,
    this.onSubmitted,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final SprInputState state;

  /// Why the last keypad key was ignored; wins over parse hints.
  final SprKeyHint? keyHint;

  /// Server-provided key text, shown only in [SprInputState.incorrect].
  final String? correctAnswer;

  /// Phone + custom keypad: system keyboard stays down.
  final bool useKeypad;
  final FocusNode? focusNode;
  final VoidCallback? onSubmitted;

  @override
  State<SprInput> createState() => _SprInputState();
}

class _SprInputState extends State<SprInput> {
  late final TextEditingController _controller;
  late final FocusNode _ownFocus;

  FocusNode get _focus => widget.focusNode ?? _ownFocus;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _ownFocus = FocusNode();
  }

  @override
  void didUpdateWidget(SprInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _ownFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.appColors;
    final text = theme.textTheme;
    final review =
        widget.state == SprInputState.correct ||
        widget.state == SprInputState.incorrect;
    final disabled = widget.state == SprInputState.disabled;
    final quiet = review || disabled;
    final preview = quiet ? null : sprPreviewTex(widget.value);
    final hint = quiet
        ? null
        : sprHintText(widget.value, keyHint: widget.keyHint);
    final helper = quiet || hint != null || preview != null
        ? null
        : widget.value.isEmpty
        ? 'Fraction, decimal or integer'
        : "Answer preview appears when it's a number";
    final valueStyle = text.titleLarge!.copyWith(
      fontWeight: FontWeight.w500,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final correctAnswer = widget.correctAnswer;
    final scaledLineHeight =
        MediaQuery.textScalerOf(context).scale(
          valueStyle.fontSize!,
        ) *
        (valueStyle.height ?? 1);
    final contentHeight = scaledLineHeight + AppSpace.s4;
    final fieldHeight = contentHeight > AppSize.largeControl
        ? contentHeight
        : AppSize.largeControl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpace.s2,
      children: [
        Text(
          'Your answer',
          style: text.labelLarge?.copyWith(
            color: disabled ? context.appColors.inkTertiary : scheme.ink,
          ),
        ),
        Wrap(
          spacing: AppSpace.s4,
          runSpacing: AppSpace.s2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSize.largeControl,
              ),
              child: SizedBox(
                width: AppSize.sprInputWidth,
                height: review ? null : fieldHeight,
                child: review
                    ? _ReviewBox(
                        value: widget.value,
                        correct: widget.state == SprInputState.correct,
                        style: valueStyle,
                      )
                    : _field(
                        context,
                        valueStyle,
                        hinted: hint != null,
                        height: fieldHeight,
                      ),
              ),
            ),
            if (preview != null) _Preview(tex: preview),
          ],
        ),
        if (hint != null) _Hint(text: hint),
        if (helper != null)
          Text(
            helper,
            style: text.bodySmall?.copyWith(color: scheme.inkSecondary),
          ),
        if (widget.state == SprInputState.incorrect && correctAnswer != null)
          _CorrectAnswer(value: correctAnswer),
      ],
    );
  }

  Widget _field(
    BuildContext context,
    TextStyle? valueStyle, {
    required bool hinted,
    required double height,
  }) {
    final scheme = context.appColors;
    final disabled = widget.state == SprInputState.disabled;
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderSide: BorderSide(color: color, width: width),
      borderRadius: BorderRadius.circular(AppRadius.control),
    );
    final onSubmitted = widget.onSubmitted;

    return Semantics(
      label: 'Your answer',
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        enabled: !disabled,
        textDirection: TextDirection.ltr,
        textInputAction: TextInputAction.done,
        textAlignVertical: TextAlignVertical.center,
        keyboardType: widget.useKeypad
            ? TextInputType.none
            : TextInputType.text,
        autocorrect: false,
        enableSuggestions: false,
        inputFormatters: sprInputFormatters,
        style: valueStyle?.copyWith(
          color: disabled ? scheme.inkTertiary : scheme.ink,
        ),
        onChanged: widget.onChanged,
        onSubmitted: onSubmitted == null ? null : (_) => onSubmitted(),
        decoration: InputDecoration(
          constraints: BoxConstraints.tightFor(height: height),
          hintText: 'Type answer',
          hintStyle: valueStyle?.copyWith(
            fontWeight: FontWeight.w400,
            color: scheme.inkTertiary,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s4,
          ),
          filled: disabled,
          fillColor: scheme.surface,
          enabledBorder: hinted ? border(scheme.brand, AppStroke.thin) : null,
          focusedBorder: hinted ? border(scheme.brand, AppStroke.strong) : null,
          disabledBorder: border(scheme.line, AppStroke.thin),
        ),
      ),
    );
  }
}
