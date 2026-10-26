import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

void main() {
  testWidgets('press_scale_0_98', (tester) async {
    var calls = 0;
    Future<void> show({bool reduced = false, bool loading = false}) =>
        tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: Scaffold(
                body: Center(
                  child: LoadingButton(
                    label: 'Continue',
                    isLoading: loading,
                    onPressed: () => calls++,
                  ),
                ),
              ),
            ),
          ),
        );
    double scale() => tester
        .widget<Transform>(
          find
              .descendant(
                of: find.byType(LoadingButton),
                matching: find.byType(Transform),
              )
              .first,
        )
        .transform
        .entry(0, 0);

    await show();
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Continue')),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(scale(), allOf(greaterThan(.98), lessThan(1)));
    await tester.pump(const Duration(milliseconds: 60));
    expect(scale(), closeTo(.98, .00001));
    expect(calls, 0);
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(scale(), 1);
    expect(calls, 1);

    await show(reduced: true);
    final reduced = await tester.startGesture(
      tester.getCenter(find.text('Continue')),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(scale(), closeTo(.98, .00001));
    await reduced.cancel();
    await tester.pump();
    expect(scale(), 1);
    await show(reduced: true, loading: true);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(scale(), 1);
    expect(calls, 1);
  });
}
