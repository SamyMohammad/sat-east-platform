import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_state.dart';
import 'package:sat_east_client/features/auth/presentation/screens/check_inbox_screen.dart';
import 'package:sat_east_client/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:sat_east_client/features/auth/presentation/screens/set_new_password_screen.dart';
import 'package:sat_east_client/features/auth/presentation/screens/sign_in_screen.dart';

import 'auth_screen_harness.dart';

void main() {
  for (final (name, size) in viewports) {
    testWidgets('S-03: Forgot password link navigates at $name', (
      tester,
    ) async {
      await pumpAuthScreen(
        tester,
        cubit: mockCubit(const AuthSignedOut()),
        screen: const SignInScreen(),
        path: AppRoutes.signIn,
        size: size,
      );
      await tester.ensureVisible(find.text('Forgot password?'));
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      expect(find.text('route:${AppRoutes.forgotPassword}'), findsOneWidget);
    });

    testWidgets('S-03: reset email validation and submission at $name', (
      tester,
    ) async {
      final cubit = mockCubit(const AuthSignedOut());
      await pumpAuthScreen(
        tester,
        cubit: cubit,
        screen: const ForgotPasswordScreen(),
        path: AppRoutes.forgotPassword,
        size: size,
      );
      expect(find.text('Reset your password'), findsOneWidget);
      expect(
        buttonOf(tester, loadingButton('Send reset link')).onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), 'invalid');
      expect(
        buttonOf(tester, loadingButton('Send reset link')).onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), ' student@example.com ');
      await tester.pump();
      await tester.tap(loadingButton('Send reset link'));
      verify(() => cubit.requestPasswordReset('student@example.com')).called(1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('S-03: reset request loading at $name', (tester) async {
      await pumpAuthScreen(
        tester,
        cubit: mockCubit(const AuthBusy()),
        screen: const ForgotPasswordScreen(),
        path: AppRoutes.forgotPassword,
        size: size,
      );
      expect(
        buttonOf(tester, loadingButton('Send reset link')).isLoading,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });

    for (final (code, copy) in [
      (ErrorCodes.linkExpired, 'This link has expired. Request a new one.'),
      (ErrorCodes.network, 'No connection. Check your internet and try again.'),
      (
        ErrorCodes.rateLimited,
        'Too many attempts. Wait a minute and try again.',
      ),
    ]) {
      testWidgets('AUTH-06: forgot password shows $code at $name', (
        tester,
      ) async {
        await pumpAuthScreen(
          tester,
          cubit: mockCubit(AuthSignedOut(error: AppError(code, 'raw detail'))),
          screen: const ForgotPasswordScreen(),
          path: AppRoutes.forgotPassword,
          size: size,
        );
        expect(find.text(copy), findsOneWidget);
        expect(find.text('raw detail'), findsNothing);
      });
    }

    testWidgets('AUTH-06: reset inbox uses enumeration-safe copy at $name', (
      tester,
    ) async {
      await pumpAuthScreen(
        tester,
        cubit: mockCubit(const AuthResetLinkSent('student@example.com')),
        screen: const CheckInboxScreen(),
        path: AppRoutes.checkInbox,
        size: size,
      );
      expect(
        find.text(
          'If an account exists for that email, '
          'we sent a reset link.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('student@example.com'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AUTH-06: password rules and matching confirmation at $name', (
      tester,
    ) async {
      final cubit = mockCubit(const AuthRecovery());
      await pumpAuthScreen(
        tester,
        cubit: cubit,
        screen: const SetNewPasswordScreen(),
        path: AppRoutes.resetPassword,
        size: size,
      );
      expect(find.text('Choose a new password'), findsOneWidget);
      final button = loadingButton('Save password');
      expect(buttonOf(tester, button).onPressed, isNull);
      for (final password in ['short1', 'abcdefgh', '12345678']) {
        await tester.enterText(find.byType(TextField).at(0), password);
        await tester.enterText(find.byType(TextField).at(1), password);
        await tester.pump();
        expect(buttonOf(tester, button).onPressed, isNull);
      }
      await tester.enterText(find.byType(TextField).at(0), 'Password1');
      await tester.enterText(find.byType(TextField).at(1), 'Different1');
      await tester.pump();
      expect(buttonOf(tester, button).onPressed, isNull);
      await tester.enterText(find.byType(TextField).at(1), 'Password1');
      await tester.pump();
      await tester.tap(button);
      verify(() => cubit.setNewPassword('Password1')).called(1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AUTH-06: password save loading at $name', (tester) async {
      await pumpAuthScreen(
        tester,
        cubit: mockCubit(const AuthRecovery(saving: true)),
        screen: const SetNewPasswordScreen(),
        path: AppRoutes.resetPassword,
        size: size,
      );
      expect(
        buttonOf(tester, loadingButton('Save password')).isLoading,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });

    for (final (code, copy) in [
      (ErrorCodes.weakPassword, 'Choose a stronger password.'),
      (ErrorCodes.network, 'No connection. Check your internet and try again.'),
      (
        ErrorCodes.rateLimited,
        'Too many attempts. Wait a minute and try again.',
      ),
    ]) {
      testWidgets('AUTH-06: password save shows $code at $name', (
        tester,
      ) async {
        await pumpAuthScreen(
          tester,
          cubit: mockCubit(AuthRecovery(error: AppError(code, 'raw detail'))),
          screen: const SetNewPasswordScreen(),
          path: AppRoutes.resetPassword,
          size: size,
        );
        expect(find.text(copy), findsOneWidget);
        expect(find.text('raw detail'), findsNothing);
      });
    }
  }
}
