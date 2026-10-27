// Feature-local imports follow the project convention.
// ignore_for_file: always_use_package_imports

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_motion.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/core/theme/app_type.dart';

import '../../domain/entities/quiz.dart';
import '../quiz_copy.dart';

class QuizResultScore extends StatefulWidget {
  const QuizResultScore({required this.report, super.key});

  final QuizReport report;

  @override
  State<QuizResultScore> createState() => _QuizResultScoreState();
}

class _QuizResultScoreState extends State<QuizResultScore>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _score;
  late final Animation<double> _badge;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    final total = AppMotion.signature + AppMotion.enter;
    final split = AppMotion.signature.inMicroseconds / total.inMicroseconds;
    _controller = AnimationController(vsync: this, duration: total);
    _score = _controller.drive(
      CurveTween(curve: Interval(0, split, curve: AppMotion.emphasized)),
    );
    _badge = _controller.drive(
      CurveTween(curve: Interval(split, 1, curve: AppMotion.emphasized)),
    );
    _scale = _badge.drive(Tween(begin: .9, end: 1));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      unawaited(_controller.forward());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final colors = context.appColors;
    final label = report.passed ? QuizCopy.passed : QuizCopy.notPassed;
    final foreground = report.passed ? colors.correct : colors.inkSecondary;
    return Column(
      spacing: AppSpace.s4,
      children: [
        AnimatedBuilder(
          animation: _score,
          builder: (context, _) {
            final value = _score.value == 1
                ? report.scorePct
                : (report.scorePct * _score.value).floorToDouble();
            final number = value == value.truncateToDouble()
                ? value.toInt().toString()
                : value.toString();
            return Semantics(
              label: QuizCopy.score(
                report.scoreRaw,
                report.scoreTotal,
                report.scorePct,
              ),
              child: ExcludeSemantics(
                child: Text(
                  '$number%',
                  key: const ValueKey('quiz-score'),
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontFeatures: AppType.count.fontFeatures,
                  ),
                ),
              ),
            );
          },
        ),
        Text(
          QuizCopy.score(report.scoreRaw, report.scoreTotal, report.scorePct),
          textAlign: TextAlign.center,
        ),
        FadeTransition(
          opacity: _badge,
          child: ScaleTransition(
            scale: _scale,
            child: Semantics(
              key: const ValueKey('quiz-result-badge'),
              liveRegion: true,
              label: label,
              child: ExcludeSemantics(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s4,
                    vertical: AppSpace.s2,
                  ),
                  decoration: BoxDecoration(
                    color: report.passed ? colors.correctWash : colors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: report.passed ? colors.correctLine : colors.line,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        report.passed ? AppIcons.correct : AppIcons.retry,
                        size: AppSize.iconSmall,
                        color: foreground,
                      ),
                      const SizedBox(width: AppSpace.s2),
                      Flexible(
                        child: RichText(
                          textAlign: TextAlign.center,
                          textScaler: MediaQuery.textScalerOf(context),
                          text: TextSpan(
                            text: label,
                            style: Theme.of(
                              context,
                            ).textTheme.labelLarge?.copyWith(color: foreground),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
