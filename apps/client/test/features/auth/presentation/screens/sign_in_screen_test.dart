import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_state.dart';
import 'package:sat_east_client/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:sat_east_client/shared/widgets/booklet_banner.dart';

import 'auth_screen_harness.dart';

void main() {
  for (final (name, size) in viewports) {
    group('P1-2: SignInScreen at $name', () {
      Future<MockAuthCubit> pump(WidgetTester tester, AuthState state) async {
        final cubit = mockCubit(state);
        await pumpAuthScreen(
          tester,
          cubit: cubit,
          screen: const SignInScreen(),
          path: '/sign-in',
          size: size,
        );
        return cubit;
      }

      testWidgets('P1-2: shows the heading, subtitle and fields', (
        tester,
      ) async {
        await pump(tester, const AuthSignedOut());

        expect(find.text('Sign in'), findsWidgets);
        expect(find.text('Your path is where you left it.'), findsOneWidget);
        expect(find.text('Email'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
        expect(find.byType(TextField), findsNWidgets(2));
        expect(loadingButton('Sign in'), findsOneWidget);
        expect(find.text('New here?'), findsOneWidget);
        expect(find.text('Create an account'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('P1-2: the sign in button is not loading by default', (
        tester,
      ) async {
        await pump(tester, const AuthSignedOut());

        expect(buttonOf(tester, loadingButton('Sign in')).isLoading, isFalse);
      });

      testWidgets('P1-2: the sign in button is loading while busy', (
        tester,
      ) async {
        await pump(tester, const AuthBusy());

        expect(buttonOf(tester, loadingButton('Sign in')).isLoading, isTrue);
        expect(tester.takeException(), isNull);
      });

      testWidgets('P1-2: submitting calls signIn with the typed values', (
        tester,
      ) async {
        final cubit = await pump(tester, const AuthSignedOut());

        await tester.enterText(find.byType(TextField).at(0), 'a@b.co');
        await tester.enterText(find.byType(TextField).at(1), 'Password1');
        await tester.tap(loadingButton('Sign in'));
        await tester.pump();

        verify(() => cubit.signIn('a@b.co', 'Password1')).called(1);
      });

      testWidgets('P1-2: the password toggle shows and hides the text', (
        tester,
      ) async {
        await pump(tester, const AuthSignedOut());
        TextField password() =>
            tester.widget<TextField>(find.byType(TextField).at(1));

        expect(password().obscureText, isTrue);
        await tester.tap(find.byTooltip('Show password'));
        await tester.pump();
        expect(password().obscureText, isFalse);
        expect(find.byTooltip('Hide password'), findsOneWidget);
        await tester.tap(find.byTooltip('Hide password'));
        await tester.pump();
        expect(password().obscureText, isTrue);
      });

      testWidgets('P1-2: Create an account goes to /sign-up', (tester) async {
        await pump(tester, const AuthSignedOut());

        await tester.tap(find.text('Create an account'));
        await tester.pumpAndSettle();

        expect(find.text('route:/sign-up'), findsOneWidget);
      });

      const errorCopy = <String, String>{
        ErrorCodes.invalidCredentials:
            "That email and password don't match. Check both for typos.",
        ErrorCodes.emailNotConfirmed:
            'Confirm your email first. Check your inbox for the link.',
        ErrorCodes.network: 'No connection. Check your internet and try again.',
        ErrorCodes.rateLimited:
            'Too many attempts. Wait a minute and try again.',
        ErrorCodes.internal: 'Something went wrong. Try again.',
        ErrorCodes.forbidden: 'Something went wrong. Try again.',
      };
      for (final entry in errorCopy.entries) {
        testWidgets('P1-2: shows the copy for ${entry.key}', (tester) async {
          await pump(tester, AuthSignedOut(error: AppError(entry.key)));

          expect(find.text(entry.value), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('P1-2: never shows raw exception text', (tester) async {
        await pump(
          tester,
          const AuthSignedOut(
            error: AppError(ErrorCodes.internal, 'PostgrestException: boom'),
          ),
        );

        expect(find.textContaining('boom'), findsNothing);
      });

      testWidgets('P1-2: shows the banner for deviceRemoved', (tester) async {
        await pump(
          tester,
          const AuthSignedOut(reason: SignOutReason.deviceRemoved),
        );

        expect(
          find.text(
            'This device was removed from your account. '
            'Sign in again to continue.',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('P1-2: shows the banner for changesExhausted', (
        tester,
      ) async {
        await pump(
          tester,
          const AuthSignedOut(reason: SignOutReason.changesExhausted),
        );

        expect(
          find.text(
            "You've used your device changes for this month. "
            'Contact your teacher.',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });

      const foreign = [ErrorCodes.emailTaken, ErrorCodes.weakPassword];
      for (final code in foreign) {
        testWidgets('P1-2: ignores the sign-up only error $code', (
          tester,
        ) async {
          await pump(tester, AuthSignedOut(error: AppError(code)));

          expect(find.byType(BookletBanner), findsNothing);
          expect(find.text('Something went wrong. Try again.'), findsNothing);
        });
      }

      testWidgets('P1-2: the removed banner shows despite a foreign error', (
        tester,
      ) async {
        await pump(
          tester,
          const AuthSignedOut(
            reason: SignOutReason.deviceRemoved,
            error: AppError(ErrorCodes.emailTaken),
          ),
        );

        expect(
          find.text(
            'This device was removed from your account. '
            'Sign in again to continue.',
          ),
          findsOneWidget,
        );
        expect(find.text('Something went wrong. Try again.'), findsNothing);
      });

      testWidgets('P1-2: keyboard submit while busy does not call signIn', (
        tester,
      ) async {
        final cubit = await pump(tester, const AuthBusy());

        await tester.enterText(find.byType(TextField).at(0), 'a@b.co');
        await tester.enterText(find.byType(TextField).at(1), 'Password1');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();

        verifyNever(() => cubit.signIn(any(), any()));
      });

      testWidgets('P1-2: calls clearError once after the first frame', (
        tester,
      ) async {
        final cubit = await pump(tester, const AuthSignedOut());

        verify(cubit.clearError).called(1);
      });

      testWidgets('P1-2: shows no banner by default', (tester) async {
        await pump(tester, const AuthSignedOut());

        expect(find.text('Something went wrong. Try again.'), findsNothing);
        expect(
          find.textContaining('This device was removed'),
          findsNothing,
        );
      });
    });
  }
}
