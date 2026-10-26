import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/router/transitions.dart';
import 'package:sat_east_client/core/theme/app_motion.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets(
      reduced
          ? 'reduced_motion_has_zero_duration'
          : 'navigation_uses_app_motion',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: Builder(
                builder: (context) {
                  for (final page in [
                    fadeThroughPage(
                      context,
                      key: const ValueKey('fade'),
                      child: const Text('Fade'),
                    ),
                    sharedAxisPage(
                      context,
                      key: const ValueKey('axis'),
                      child: const Text('Axis'),
                    ),
                  ]) {
                    expect(page, isA<CustomTransitionPage<void>>());
                    expect(
                      page.transitionDuration,
                      reduced ? Duration.zero : AppMotion.enter,
                    );
                    expect(
                      page.reverseTransitionDuration,
                      reduced ? Duration.zero : AppMotion.enter,
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
