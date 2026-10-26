import 'dart:async';

import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_motion.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/margin_note.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/worked_example.dart';
import 'package:sat_east_client/shared/widgets/question_view/practice_feedback.dart';

/// Pinned practice action and server feedback. Submission is latched locally
/// until the caller supplies a new feedback state or answer-enabled callback.
class FeedbackDock extends StatefulWidget {
  const FeedbackDock({
    required this.feedback,
    required this.onCheck,
    required this.actions,
    super.key,
    this.author,
    this.questionLabel = '',
  });

  final PracticeFeedback? feedback;
  final VoidCallback? onCheck;
  final List<Widget> actions;
  final String? author;
  final String questionLabel;

  @override
  State<FeedbackDock> createState() => _FeedbackDockState();
}

class _FeedbackDockState extends State<FeedbackDock>
    with SingleTickerProviderStateMixin {
  static final Duration _sequenceDuration = AppMotion.enter + AppMotion.press;

  late final AnimationController _reveal;
  bool _submitted = false;

  bool get _verdict => switch (widget.feedback) {
    Correct() || FirstMiss() || Revealed() => true,
    _ => false,
  };

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(vsync: this, value: _verdict ? 1 : 0);
  }

  @override
  void didUpdateWidget(FeedbackDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.feedback != widget.feedback) {
      _submitted = false;
      _reveal.duration = AppMotion.resolve(
        context,
        _sequenceDuration,
      );
      if (!_verdict) {
        _reveal.value = 0;
      } else if (AppMotion.reduced(context)) {
        _reveal.value = 1;
      } else {
        unawaited(_reveal.forward(from: 0));
      }
    } else if (oldWidget.onCheck == null && widget.onCheck != null) {
      _submitted = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) _reveal.value = _verdict ? 1 : 0;
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  void _check() {
    if (_submitted || widget.onCheck == null || widget.feedback is Checking) {
      return;
    }
    setState(() => _submitted = true);
    widget.onCheck!();
  }

  Animation<double> _phase(Duration delay) => _reveal.drive(
    CurveTween(
      curve: Interval(
        delay.inMicroseconds / _sequenceDuration.inMicroseconds,
        (delay + AppMotion.enter).inMicroseconds /
            _sequenceDuration.inMicroseconds,
        curve: AppMotion.emphasized,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final correct = widget.feedback is Correct;
    final accent = correct ? colors.correct : colors.incorrect;
    final wash = correct ? colors.correctWash : colors.incorrectWash;
    final line = correct ? colors.correctLine : colors.incorrectLine;
    final title = correct ? 'Correct' : 'Not quite';
    final terminal = widget.feedback is Correct || widget.feedback is Revealed;
    final teacher = switch (widget.feedback) {
      Correct(:final noteMd) => noteMd ?? '',
      Revealed(:final noteMd) => noteMd,
      FirstMiss(:final noteMd, :final hintMd) => noteMd ?? hintMd,
      _ => null,
    };
    final explanation = switch (widget.feedback) {
      Correct(:final explanationMd) ||
      Revealed(:final explanationMd) => explanationMd,
      _ => null,
    };
    final verdictAnimation = _phase(AppMotion.stagger);
    final teacherAnimation = _phase(AppMotion.press);

    return AnimatedBuilder(
      animation: _reveal,
      builder: (context, child) => DecoratedBox(
        key: const ValueKey('dock-tint'),
        decoration: BoxDecoration(
          color: Color.lerp(
            colors.background,
            wash,
            _verdict
                ? AppMotion.emphasized.transform(
                    (_reveal.value *
                            _sequenceDuration.inMilliseconds /
                            AppMotion.enter.inMilliseconds)
                        .clamp(0, 1),
                  )
                : 0,
          ),
          border: Border(top: BorderSide(color: _verdict ? line : colors.line)),
          boxShadow: _verdict
              ? [
                  BoxShadow(
                    color: colors.shadow,
                    blurRadius: AppSpace.s4,
                    offset: const Offset(0, -2),
                  ),
                ]
              : null,
        ),
        child: child,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.45,
        ),
        child: SafeArea(
          top: false,
          child: Align(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSize.questionColumn,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s4,
                  vertical: AppSpace.s3,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact =
                        constraints.maxWidth + AppSpace.s4 * 2 < 600;
                    final actionContent = Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: compact
                          ? CrossAxisAlignment.stretch
                          : CrossAxisAlignment.end,
                      spacing: AppSpace.s2,
                      children: [
                        ...widget.actions,
                        if (!terminal)
                          LoadingButton(
                            label: 'Check',
                            expanded: compact,
                            isLoading: widget.feedback is Checking,
                            onPressed: !_submitted
                                ? widget.onCheck == null
                                      ? null
                                      : _check
                                : null,
                          ),
                      ],
                    );
                    final actions = Theme(
                      data: Theme.of(context).copyWith(
                        extensions: [
                          ...Theme.of(context).extensions.values.where(
                            (extension) => extension is! AppColors,
                          ),
                          if (_verdict)
                            colors.copyWith(
                              brand: accent,
                              onBrand: colors.background,
                              brandWash: wash,
                              brandLine: line,
                            )
                          else
                            colors,
                        ],
                      ),
                      child: actionContent,
                    );
                    final feedback = SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: AppSpace.s3,
                        children: [
                          FadeTransition(
                            key: const ValueKey('dock-verdict'),
                            alwaysIncludeSemantics: true,
                            opacity: verdictAnimation,
                            child: SlideTransition(
                              position: verdictAnimation.drive(
                                Tween(
                                  begin: const Offset(0, 0.15),
                                  end: Offset.zero,
                                ),
                              ),
                              child: Semantics(
                                key: const ValueKey('dock-announcement'),
                                container: true,
                                liveRegion: true,
                                excludeSemantics: true,
                                label: title,
                                child: Row(
                                  spacing: AppSpace.s3,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(
                                        AppSpace.s2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: accent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        correct
                                            ? AppIcons.correct
                                            : AppIcons.incorrect,
                                        color: colors.background,
                                        size: AppSize.iconSmall,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              color: accent,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          FadeTransition(
                            key: const ValueKey('dock-teacher'),
                            opacity: teacherAnimation,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              spacing: AppSpace.s3,
                              children: [
                                if (teacher != null)
                                  MarginNote(
                                    tone: correct
                                        ? MarginNoteTone.correct
                                        : MarginNoteTone.miss,
                                    author: widget.author,
                                    bodyMd: teacher,
                                    teacherLine: true,
                                  ),
                                if (explanation != null)
                                  WorkedExample(
                                    label: widget.questionLabel,
                                    md: explanation,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                    if (!compact) {
                      return Row(
                        spacing: AppSpace.s6,
                        children: [
                          if (_verdict)
                            Expanded(child: feedback)
                          else
                            const Spacer(),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: constraints.maxWidth * 0.4,
                            ),
                            child: actions,
                          ),
                        ],
                      );
                    }
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: AppSpace.s3,
                      children: [
                        if (_verdict) Flexible(child: feedback),
                        actions,
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
