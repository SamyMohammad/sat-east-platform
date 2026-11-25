import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/auth/presentation/auth_copy.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_state.dart';
import 'package:sat_east_client/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:sat_east_client/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:sat_east_client/features/auth/presentation/screens/sign_up_screen.dart';

import 'auth_screen_harness.dart';
import 'fake_captcha.dart';

const _size = Size(1280, 800);

Future<void> _solve(WidgetTester tester) async {
  await tester.tap(find.text('Solve captcha'));
  await tester.pump();
}

bool _enabled(WidgetTester tester, String label) =>
    buttonOf(tester, loadingButton(label)).onPressed != null;

void main() {
  group('P3-1: sign in with captcha configured', () {
    late FakeCaptcha captcha;
    late MockAuthCubit cubit;

    setUp(() => captcha = FakeCaptcha());

    Future<void> pump(WidgetTester tester) async {
      cubit = mockCubit(const AuthSignedOut());
      await pumpAuthScreen(
        tester,
        cubit: cubit,
        screen: const SignInScreen(),
        path: '/sign-in',
        size: _size,
        captcha: captcha,
      );
      await tester.enterText(find.byType(TextField).at(0), 'a@b.co');
      await tester.enterText(find.byType(TextField).at(1), 'Password1');
      await tester.pump();
    }

    testWidgets('P3-1: submit is disabled until a token exists', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Solve captcha'), findsOneWidget);
      expect(_enabled(tester, 'Sign in'), isFalse);

      await _solve(tester);

      expect(_enabled(tester, 'Sign in'), isTrue);
    });

    testWidgets('P3-1: submit sends the token, then resets the widget', (
      tester,
    ) async {
      await pump(tester);
      await _solve(tester);

      await tester.tap(loadingButton('Sign in'));
      await tester.pump();

      verify(
        () => cubit.signIn('a@b.co', 'Password1', captchaToken: 'tok'),
      ).called(1);
      expect(captcha.resets, 1);
      expect(_enabled(tester, 'Sign in'), isFalse);
    });

    testWidgets('P3-1: shows the captcha failure copy', (tester) async {
      cubit = mockCubit(
        const AuthSignedOut(error: AppError(ErrorCodes.captchaFailed)),
      );
      await pumpAuthScreen(
        tester,
        cubit: cubit,
        screen: const SignInScreen(),
        path: '/sign-in',
        size: _size,
        captcha: captcha,
      );

      expect(
        find.text(authErrorCopy(ErrorCodes.captchaFailed)),
        findsOneWidget,
      );
    });
  });

  group('P3-1: sign up with captcha configured', () {
    testWidgets('P3-1: gated by the token and sends it', (tester) async {
      final captcha = FakeCaptcha();
      final cubit = mockCubit(const AuthSignedOut());
      await pumpAuthScreen(
        tester,
        cubit: cubit,
        screen: const SignUpScreen(),
        path: '/sign-up',
        size: _size,
        captcha: captcha,
      );
      await tester.enterText(find.byType(TextField).at(0), 'Sam Ali');
      await tester.enterText(find.byType(TextField).at(1), 'a@b.co');
      await tester.enterText(find.byType(TextField).at(2), 'Password1');
      await tester.pump();

      expect(_enabled(tester, 'Create account'), isFalse);

      await _solve(tester);
      expect(_enabled(tester, 'Create account'), isTrue);

      await tester.tap(loadingButton('Create account'));
      await tester.pump();

      verify(
        () => cubit.signUp(
          'a@b.co',
          'Password1',
          'Sam Ali',
          captchaToken: 'tok',
        ),
      ).called(1);
      expect(captcha.resets, 1);
    });
  });

  group('P3-1: forgot password with captcha configured', () {
    testWidgets('P3-1: gated by the token and sends it', (tester) async {
      final captcha = FakeCaptcha();
      final cubit = mockCubit(const AuthSignedOut());
      await pumpAuthScreen(
        tester,
        cubit: cubit,
        screen: const ForgotPasswordScreen(),
        path: '/forgot-password',
        size: _size,
        captcha: captcha,
      );
      await tester.enterText(find.byType(TextField), 'a@b.co');
      await tester.pump();

      expect(_enabled(tester, 'Send reset link'), isFalse);

      await _solve(tester);
      expect(_enabled(tester, 'Send reset link'), isTrue);

      await tester.tap(loadingButton('Send reset link'));
      await tester.pump();

      verify(
        () => cubit.requestPasswordReset('a@b.co', captchaToken: 'tok'),
      ).called(1);
      expect(captcha.resets, 1);
    });
  });

  group('P3-1: captcha off (empty site key)', () {
    testWidgets('P3-1: sign in has no widget and sends no token', (
      tester,
    ) async {
      final cubit = mockCubit(const AuthSignedOut());
      await pumpAuthScreen(
        tester,
        cubit: cubit,
        screen: const SignInScreen(),
        path: '/sign-in',
        size: _size,
      );
      await tester.enterText(find.byType(TextField).at(0), 'a@b.co');
      await tester.enterText(find.byType(TextField).at(1), 'Password1');
      await tester.pump();

      expect(find.text('Solve captcha'), findsNothing);
      expect(_enabled(tester, 'Sign in'), isTrue);

      await tester.tap(loadingButton('Sign in'));
      await tester.pump();

      verify(
        () => cubit.signIn(
          'a@b.co',
          'Password1',
          captchaToken: any(named: 'captchaToken', that: isNull),
        ),
      ).called(1);
    });

    testWidgets('P3-1: forgot password stays ungated', (tester) async {
      final cubit = mockCubit(const AuthSignedOut());
      await pumpAuthScreen(
        tester,
        cubit: cubit,
        screen: const ForgotPasswordScreen(),
        path: '/forgot-password',
        size: _size,
      );
      await tester.enterText(find.byType(TextField), 'a@b.co');
      await tester.pump();

      expect(_enabled(tester, 'Send reset link'), isTrue);
      await tester.tap(loadingButton('Send reset link'));
      await tester.pump();
      verify(
        () => cubit.requestPasswordReset(
          'a@b.co',
          captchaToken: any(named: 'captchaToken', that: isNull),
        ),
      ).called(1);
    });
  });
}
