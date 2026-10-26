import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/shared/widgets/app_auth_card.dart';
import 'package:sat_east_client/shared/widgets/app_illustration.dart';
import 'package:sat_east_client/shared/widgets/app_shell/shell_header.dart';

void main() {
  for (final width in [360.0, 959.0, 960.0, 1280.0]) {
    for (final dark in [false, true]) {
      testWidgets('auth layout at $width, dark: $dark', (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            home: const AppAuthCard(
              showWelcomeIllustration: true,
              children: [Text('Form title'), TextField()],
            ),
          ),
        );
        final panes = find.byKey(const ValueKey('auth-panes'));
        final wide = width >= 960;
        expect(panes, wide ? findsOneWidget : findsNothing);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.byType(AppIllustration), findsOneWidget);
        if (wide) {
          expect(tester.getSize(panes).width, lessThanOrEqualTo(1040));
          if (width == 1280) {
            expect(tester.getSize(panes).width, 1040);
            expect(tester.getCenter(panes).dx, 640);
          }
          final decoration =
              tester
                      .widget<DecoratedBox>(
                        find.byKey(const ValueKey('auth-welcome-pane')),
                      )
                      .decoration
                  as BoxDecoration;
          expect(
            decoration.color,
            dark ? AppColors.dark.brandWash : AppColors.light.brandWash,
          );
          expect(decoration.borderRadius, BorderRadius.circular(16));
          expect(
            tester.getSize(find.byType(AppIllustration)).height,
            lessThanOrEqualTo(280),
          );
        }
        final brand = find.descendant(
          of: find.byType(Card),
          matching: find.byType(ShellWordmark),
        );
        expect(
          tester.getTopLeft(find.text('Form title')).dy -
              tester.getBottomLeft(brand).dy,
          24,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
