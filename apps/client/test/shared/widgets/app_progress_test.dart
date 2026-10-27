import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/shared/widgets/app_progress.dart';

void main() {
  testWidgets('segment_fill_animates_and_respects_reduced_motion', (
    tester,
  ) async {
    final theme = AppTheme.light();
    Future<void> show(double value, {bool reduced = false}) =>
        tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: Scaffold(
                body: AppProgress(label: 'Progress', value: value),
              ),
            ),
          ),
        );
    double fill() => tester
        .widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        )
        .value!;

    await show(0);
    await show(1);
    expect(fill(), 0);
    await tester.pump(const Duration(milliseconds: 100));
    expect(fill(), allOf(greaterThan(0), lessThan(1)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(fill(), 1);
    await show(0, reduced: true);
    expect(fill(), 0);
    await show(0);
    await show(1);
    await tester.pump(const Duration(milliseconds: 100));
    expect(fill(), allOf(greaterThan(0), lessThan(1)));
    await show(1, reduced: true);
    expect(fill(), 1);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
