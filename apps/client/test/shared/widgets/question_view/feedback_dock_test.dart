import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/feedback_dock.dart';
import 'package:sat_east_client/shared/widgets/question_view/parts/margin_note.dart';
import 'package:sat_east_client/shared/widgets/question_view/practice_feedback.dart';

const _result = Correct(noteMd: 'Clean work. Divide both sides by 3.');

final ThemeData _theme = AppTheme.light();

Widget _app(
  PracticeFeedback feedback, {
  bool reduced = false,
  VoidCallback? check,
}) => MaterialApp(
  theme: _theme,
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
      child: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: FeedbackDock(
            feedback: feedback,
            onCheck: check,
            actions: const [],
          ),
        ),
      ),
    ),
  ),
);

double _opacity(WidgetTester t, String key) =>
    t.widget<FadeTransition>(find.byKey(ValueKey(key))).opacity.value;

void main() {
  testWidgets('PRC-03: equal feedback on rebuild does not replay the reveal', (
    t,
  ) async {
    // Fresh, non-const instances: the screen rebuilds them on every tap.
    final note = ['Not', 'quite.'].join(' ');
    FirstMiss miss() => FirstMiss(missed: 'A', noteMd: note);
    await t.pumpWidget(_app(miss()));
    await t.pumpAndSettle();
    await t.pumpWidget(_app(miss()));
    // A replay would restart the verdict fade from 0.
    expect(_opacity(t, 'dock-verdict'), 1);
  });

  testWidgets('PRC-03: correct without a teacher note shows no note box', (
    t,
  ) async {
    await t.pumpWidget(_app(const Correct(explanationMd: 'x'), reduced: true));
    expect(find.byType(MarginNote), findsNothing);
  });

  testWidgets('check_sequence_order', (t) async {
    await t.pumpWidget(_app(const Idle()));
    await t.pumpWidget(_app(_result));
    expect(_opacity(t, 'dock-verdict'), 0);
    expect(_opacity(t, 'dock-teacher'), 0);
    await t.pump(const Duration(milliseconds: 40));
    final decoration =
        t
                .widget<DecoratedBox>(find.byKey(const ValueKey('dock-tint')))
                .decoration
            as BoxDecoration;
    expect(decoration.color, isNot(AppColors.light.background));
    expect(_opacity(t, 'dock-teacher'), 0);
    await t.pump(const Duration(milliseconds: 40));
    expect(_opacity(t, 'dock-verdict'), greaterThan(0));
    expect(_opacity(t, 'dock-teacher'), 0);
    await t.pump(const Duration(milliseconds: 120));
    expect(_opacity(t, 'dock-teacher'), greaterThan(0));
    await t.pumpAndSettle();
  });

  testWidgets('check_reduced_motion_shows_final_state', (t) async {
    await t.pumpWidget(_app(const Idle(), reduced: true));
    await t.pumpWidget(_app(_result, reduced: true));
    expect(_opacity(t, 'dock-verdict'), 1);
    expect(_opacity(t, 'dock-teacher'), 1);
    expect(t.hasRunningAnimations, isFalse);
  });

  testWidgets('check_double_tap_submits_once', (t) async {
    var checks = 0;
    await t.pumpWidget(_app(const Idle(), check: () => checks++));
    await t.tap(find.text('Check'));
    await t.tap(find.text('Check'));
    expect(checks, 1);
    await t.pumpAndSettle();
  });

  testWidgets('verdict_announced_live_region', (t) async {
    final handle = t.ensureSemantics();
    await t.pumpWidget(_app(const Idle(), check: () {}));
    await t.tap(find.text('Check'));
    await t.pumpWidget(_app(_result));
    final node = t.getSemantics(
      find.byKey(const ValueKey('dock-announcement')),
    );
    expect(node.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
    expect(node.label, contains('Correct'));
    await t.pumpAndSettle();
    handle.dispose();
  });

  testWidgets('wrong_answer_shows_icon_and_word_not_colour_only', (t) async {
    await t.pumpWidget(_app(const FirstMiss(missed: 'A'), reduced: true));
    expect(find.text('Not quite'), findsOneWidget);
    expect(find.byIcon(AppIcons.incorrect), findsOneWidget);
  });
}
