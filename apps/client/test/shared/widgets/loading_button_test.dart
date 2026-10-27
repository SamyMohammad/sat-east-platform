import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';
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
  for (final (name, theme, colors) in [
    ('light', AppTheme.light(), AppColors.light),
    ('dark', AppTheme.dark(), AppColors.dark),
  ]) {
    testWidgets('destructive uses danger roles and hover shade ($name)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Center(
              child: LoadingButton(
                label: 'Delete',
                variant: AppButtonVariant.destructive,
                onPressed: () {},
              ),
            ),
          ),
        ),
      );
      Color? fill() => tester
          .widget<Material>(
            find
                .descendant(
                  of: find.byType(FilledButton),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color;
      expect(fill(), colors.danger);
      expect(
        tester.widget<Text>(find.text('Delete')).style?.color ??
            DefaultTextStyle.of(
              tester.element(find.text('Delete')),
            ).style.color,
        colors.onDanger,
      );

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('Delete')));
      await tester.pumpAndSettle();
      expect(fill(), colors.dangerHover);
    });
  }
}
