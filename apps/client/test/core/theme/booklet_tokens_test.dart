// test/core/theme/booklet_tokens_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';

void main() {
  test('F-4: layout breakpoints follow the app shell (600 / 1024)', () {
    expect(BookletLayout.forWidth(360), BookletLayout.compact);
    expect(BookletLayout.forWidth(600), BookletLayout.compact);
    expect(BookletLayout.forWidth(768), BookletLayout.medium);
    expect(BookletLayout.forWidth(1023), BookletLayout.medium);
    expect(BookletLayout.forWidth(1024), BookletLayout.expanded);
    expect(BookletLayout.forWidth(1280), BookletLayout.expanded);
  });

  test('F-4: touch target is 48 and spacing is on the 4-pt grid', () {
    expect(BookletSize.touchTarget, 48);
    for (final v in [
      BookletSpace.s1,
      BookletSpace.s2,
      BookletSpace.s3,
      BookletSpace.s4,
      BookletSpace.s6,
      BookletSpace.s8,
      BookletSpace.s12,
      BookletSpace.s16,
    ]) {
      expect(v % 4, 0);
    }
  });

  test('F-4: answer controls are 56 and the badge centres in a 48 row', () {
    expect(BookletSize.largeControl, 56);
    expect((BookletSize.touchTarget - BookletSize.choiceBadge) / 2, 10);
    expect(BookletStroke.strong - BookletStroke.thin, 1);
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
            result = BookletMotion.resolve(context, duration);
            return const SizedBox();
          },
        ),
      ),
    );
    return result;
  }

  testWidgets('F-4: motion is unchanged without reduced motion', (t) async {
    expect(
      await resolveWith(t, reduced: false, duration: BookletMotion.slow),
      BookletMotion.slow,
    );
  });

  testWidgets('F-4: reduced motion makes slow instant', (t) async {
    expect(
      await resolveWith(t, reduced: true, duration: BookletMotion.slow),
      Duration.zero,
    );
  });

  testWidgets('F-4: reduced motion turns base into fast', (t) async {
    expect(
      await resolveWith(t, reduced: true, duration: BookletMotion.base),
      BookletMotion.fast,
    );
  });
}
