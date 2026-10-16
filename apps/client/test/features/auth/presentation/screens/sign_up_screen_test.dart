import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_state.dart';
import 'package:sat_east_client/features/auth/presentation/screens/sign_up_screen.dart';

import 'auth_screen_harness.dart';

void main() {
  for (final (name, size) in viewports) {
    group('P1-2: SignUpScreen at $name', () {
      Future<MockAuthCubit> pump(WidgetTester tester, AuthState state) async {
        final cubit = mockCubit(state);
        await pumpAuthScreen(
          tester,
          cubit: cubit,
          screen: const SignUpScreen(),
          path: '/sign-up',
          size: size,
        );
        return cubit;
      }

      Future<void> fill(
        WidgetTester tester, {
        String name = 'Sam Ali',
        String email = 'a@b.co',
        String password = 'Password1',
      }) async {
        await tester.enterText(find.byType(TextField).at(0), name);
        await tester.enterText(find.byType(TextField).at(1), email);
        await tester.enterText(find.byType(TextField).at(2), password);
        await tester.pump();
      }

      bool enabled(WidgetTester tester) =>
          buttonOf(tester, loadingButton('Create account')).onPressed != null;

      testWidgets('P1-2: shows the heading, subtitle, fields and legal', (
        tester,
      ) async {
        await pump(tester, const AuthSignedOut());

        expect(find.text('Create your account'), findsOneWidget);
        expect(
          find.text(
            'Use the email you check most. Receipts and reset links go there.',
          ),
          findsOneWidget,
        );
        expect(find.text('Full name'), findsOneWidget);
        expect(find.text('Email'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
        expect(find.byType(TextField), findsNWidgets(3));
        expect(
          find.text(
            'By creating an account you agree to the Terms and Privacy policy.',
          ),
          findsOneWidget,
        );
        expect(find.text('Already have an account?'), findsOneWidget);
        expect(find.text('Sign in'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('P1-2: all three rules start unmet', (tester) async {
        await pump(tester, const AuthSignedOut());

        expect(find.text('A number'), findsOneWidget);
        expect(find.text('A letter'), findsOneWidget);
        expect(find.textContaining('At least 8 characters'), findsOneWidget);
        expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(3));
        expect(find.byIcon(Icons.check_circle), findsNothing);
      });

      testWidgets('P1-2: the length rule counts characters so far', (
        tester,
      ) async {
        await pump(tester, const AuthSignedOut());

        await tester.enterText(find.byType(TextField).at(2), 'abc');
        await tester.pump();

        expect(find.textContaining('3 so far'), findsOneWidget);
      });

      testWidgets('P1-2: letter and number rules tick live', (tester) async {
        await pump(tester, const AuthSignedOut());

        await tester.enterText(find.byType(TextField).at(2), 'abc');
        await tester.pump();
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(2));

        await tester.enterText(find.byType(TextField).at(2), 'abc1');
        await tester.pump();
        expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
        expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
      });

      testWidgets('P1-2: all rules met removes the so far hint', (
        tester,
      ) async {
        await pump(tester, const AuthSignedOut());

        await tester.enterText(find.byType(TextField).at(2), 'abcdefg1');
        await tester.pump();

        expect(find.byIcon(Icons.check_circle), findsNWidgets(3));
        expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
        expect(find.textContaining('so far'), findsNothing);
      });

      testWidgets('P1-2: Create account is disabled when the form is empty', (
        tester,
      ) async {
        await pump(tester, const AuthSignedOut());

        expect(enabled(tester), isFalse);
      });

      testWidgets('P1-2: Create account is enabled when the form is valid', (
        tester,
      ) async {
        await pump(tester, const AuthSignedOut());

        await fill(tester);

        expect(enabled(tester), isTrue);
      });

      testWidgets('P1-2: Create account is disabled for a blank name', (
        tester,
      ) async {
        await pump(tester, const AuthSignedOut());

        await fill(tester, name: '   ');

        expect(enabled(tester), isFalse);
      });

      testWidgets('P1-2: Create account is disabled for a bad email', (
        tester,
      ) async {
        await pump(tester, const AuthSignedOut());

        await fill(tester, email: 'not-an-email');

        expect(enabled(tester), isFalse);
      });

      const weak = <String, String>{
        'too short': 'abc1',
        'no number': 'abcdefgh',
        'no letter': '12345678',
      };
      for (final entry in weak.entries) {
        testWidgets('P1-2: Create account is disabled for ${entry.key}', (
          tester,
        ) async {
          await pump(tester, const AuthSignedOut());

          await fill(tester, password: entry.value);

          expect(enabled(tester), isFalse);
        });
      }

      testWidgets('P1-2: submitting calls signUp with the typed values', (
        tester,
      ) async {
        final cubit = await pump(tester, const AuthSignedOut());
        await fill(tester);

        await tester.tap(loadingButton('Create account'));
        await tester.pump();

        verify(() => cubit.signUp('a@b.co', 'Password1', 'Sam Ali')).called(1);
      });

      testWidgets('P1-2: Create account is loading while busy', (tester) async {
        await pump(tester, const AuthBusy());

        expect(
          buttonOf(tester, loadingButton('Create account')).isLoading,
          isTrue,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('P1-2: the Sign in footer link goes to /sign-in', (
        tester,
      ) async {
        await pump(tester, const AuthSignedOut());

        await tester.tap(find.text('Sign in'));
        await tester.pumpAndSettle();

        expect(find.text('route:/sign-in'), findsOneWidget);
      });

      testWidgets('P1-2: emailTaken shows inline copy and a sign in link', (
        tester,
      ) async {
        await pump(
          tester,
          const AuthSignedOut(error: AppError(ErrorCodes.emailTaken)),
        );

        expect(
          find.text('This email already has an account.'),
          findsOneWidget,
        );
        expect(find.text('Sign in instead'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('P1-2: Sign in instead goes to /sign-in', (tester) async {
        await pump(
          tester,
          const AuthSignedOut(error: AppError(ErrorCodes.emailTaken)),
        );

        await tester.tap(find.text('Sign in instead'));
        await tester.pumpAndSettle();

        expect(find.text('route:/sign-in'), findsOneWidget);
      });

      testWidgets('P1-2: weakPassword shows the stronger password copy', (
        tester,
      ) async {
        await pump(
          tester,
          const AuthSignedOut(error: AppError(ErrorCodes.weakPassword)),
        );

        expect(find.text('Choose a stronger password.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
