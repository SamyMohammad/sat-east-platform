// test/core/theme/app_tokens_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/theme/app_motion.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';

void main() {
  test('F-4: layout breakpoints follow the app shell (600 / 1024)', () {
    expect(AppLayout.forWidth(360), AppLayout.compact);
    expect(AppLayout.forWidth(600), AppLayout.compact);
    expect(AppLayout.forWidth(768), AppLayout.medium);
    expect(AppLayout.forWidth(1023), AppLayout.medium);
    expect(AppLayout.forWidth(1024), AppLayout.expanded);
    expect(AppLayout.forWidth(1280), AppLayout.expanded);
  });

  test('F-4: touch target is 48 and spacing is on the 4-pt grid', () {
    expect(AppSize.touchTarget, 48);
    for (final v in [
      AppSpace.s1,
      AppSpace.s2,
      AppSpace.s3,
      AppSpace.s4,
      AppSpace.s6,
      AppSpace.s8,
      AppSpace.s12,
      AppSpace.s16,
    ]) {
      expect(v % 4, 0);
    }
  });

  test('F-4: answer controls are 56 and the badge centres in a 48 row', () {
    expect(AppSize.largeControl, 56);
    expect((AppSize.touchTarget - AppSize.choiceBadge) / 2, 9);
    expect(AppStroke.strong - AppStroke.thin, 1);
  });

  Future<Duration> resolveWith(
    WidgetTester tester, {
    required bool reduced,
    required Duration duration,
  }) async {
    late Duration result;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Builder(
          builder: (context) {
            result = AppMotion.resolve(context, duration);
            return const SizedBox();
          },
        ),
      ),
    );
    return result;
  }

  testWidgets('F-4: motion is unchanged without reduced motion', (t) async {
    expect(
      await resolveWith(t, reduced: false, duration: AppMotion.enter),
      AppMotion.enter,
    );
  });

  testWidgets('F-4: reduced motion makes slow instant', (t) async {
    expect(
      await resolveWith(t, reduced: true, duration: AppMotion.enter),
      Duration.zero,
    );
  });

  testWidgets('F-4: reduced motion makes base instant', (t) async {
    expect(
      await resolveWith(t, reduced: true, duration: AppMotion.state),
      Duration.zero,
    );
  });
}
