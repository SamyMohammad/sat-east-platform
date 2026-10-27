import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/theme/app_motion.dart';

void main() {
  for (final disabled in [true, false]) {
    testWidgets(
      disabled
          ? 'resolve_returns_zero_when_disable_animations'
          : 'resolve_returns_duration_otherwise',
      (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(disableAnimations: disabled),
            child: Builder(
              builder: (context) {
                expect(AppMotion.reduced(context), disabled);
                for (final duration in [
                  Duration.zero,
                  AppMotion.press,
                  AppMotion.state,
                  AppMotion.enter,
                  AppMotion.signature,
                  AppMotion.stagger,
                ]) {
                  expect(
                    AppMotion.resolve(context, duration),
                    disabled ? Duration.zero : duration,
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        );
      },
    );
  }
}
