import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/router/placeholder_screen.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_state.dart';
import 'package:sat_east_client/features/auth/presentation/screens/check_inbox_screen.dart';
import 'package:sat_east_client/features/auth/presentation/screens/device_gate_screen.dart';
import 'package:sat_east_client/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:sat_east_client/features/auth/presentation/screens/set_new_password_screen.dart';
import 'package:sat_east_client/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:sat_east_client/features/auth/presentation/screens/sign_up_screen.dart';
import 'package:sat_east_client/shared/widgets/app_illustration.dart';
import 'package:sat_east_client/shared/widgets/icon_tile.dart';

import 'auth_screen_harness.dart';

void main() {
  for (final (name, size) in viewports) {
    for (final (screen, path, state, illustration)
        in <(Widget, String, AuthState, AppIllustrationName?)>[
          (const SignInScreen(), '/sign-in', const AuthSignedOut(), null),
          (const SignUpScreen(), '/sign-up', const AuthSignedOut(), null),
          (
            const CheckInboxScreen(),
            '/check-inbox',
            const AuthConfirmationSent('a@b.co'),
            AppIllustrationName.inbox,
          ),
          (
            const ForgotPasswordScreen(),
            '/forgot-password',
            const AuthSignedOut(),
            AppIllustrationName.resetPassword,
          ),
          (
            const SetNewPasswordScreen(),
            '/reset-password',
            const AuthRecovery(),
            AppIllustrationName.resetPassword,
          ),
          (
            const SetNewPasswordScreen(),
            '/reset-password',
            const AuthSignedOut(),
            AppIllustrationName.resetPassword,
          ),
          (
            const DeviceGateScreen(),
            '/devices',
            const AuthDeviceGate(devices: [], changesLeft: 1),
            AppIllustrationName.deviceLimit,
          ),
        ]) {
      testWidgets(
        'auth card brand and illustration: $path ${state.runtimeType} at $name',
        (tester) async {
          await pumpAuthScreen(
            tester,
            cubit: mockCubit(state),
            screen: screen,
            path: path,
            size: size,
          );
          final wide = size.width >= 960;
          expect(
            find.text('Abdelrahman Elmenshawy'),
            findsOneWidget,
          );
          expect(find.text('SAT & EST Math'), findsOneWidget);
          expect(find.byType(Card), findsOneWidget);
          expect(
            tester.getSize(find.byType(Card)).width,
            lessThanOrEqualTo(AppSize.authCard),
          );
          if (illustration != null) {
            expect(
              find.byWidgetPredicate(
                (widget) =>
                    widget is AppIllustration && widget.name == illustration,
              ),
              findsOneWidget,
            );
          }
          final welcome = find.byWidgetPredicate(
            (widget) =>
                widget is AppIllustration &&
                widget.name == AppIllustrationName.welcome,
          );
          final entry = screen is SignInScreen;
          expect(welcome, wide || entry ? findsOneWidget : findsNothing);
          if (wide) {
            expect(
              find.text('Build confidence, one topic at a time.'),
              findsOneWidget,
            );
            expect(
              tester.getTopRight(welcome).dx,
              lessThan(tester.getTopLeft(find.byType(Card)).dx),
            );
          } else if (entry) {
            expect(tester.getSize(welcome).height, 120);
            expect(
              tester.getBottomLeft(welcome).dy,
              lessThan(
                tester.getTopLeft(find.text('Abdelrahman Elmenshawy')).dy,
              ),
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final (screen, path) in [
    (const SignInScreen(), '/sign-in'),
    (const SignUpScreen(), '/sign-up'),
  ]) {
    testWidgets('single auth card at 360 with 2x text: $path', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpAuthScreen(
        tester,
        cubit: mockCubit(const AuthSignedOut()),
        screen: screen,
        path: path,
        size: const Size(360, 800),
      );
      expect(find.byType(Card), findsOneWidget);
      expect(find.text('Build confidence, one topic at a time.'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -1800),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  for (final (title, icon) in [
    ('Skills', AppIcons.skills),
    ('Mock exams', AppIcons.mockExams),
  ]) {
    testWidgets('placeholder uses destination icon: $title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: PlaceholderScreen(title: title)),
        ),
      );
      expect(tester.widget<IconTile>(find.byType(IconTile)).icon, icon);
      expect(find.text('This page will be available soon.'), findsOneWidget);
    });
  }
}
