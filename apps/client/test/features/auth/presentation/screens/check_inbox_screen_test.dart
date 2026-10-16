import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_state.dart';
import 'package:sat_east_client/features/auth/presentation/screens/check_inbox_screen.dart';
import 'package:sat_east_client/shared/widgets/booklet_status_frame.dart';

import 'auth_screen_harness.dart';

void main() {
  for (final (name, size) in viewports) {
    group('P1-2: CheckInboxScreen at $name', () {
      Future<void> pump(WidgetTester tester) => pumpAuthScreen(
        tester,
        cubit: mockCubit(const AuthConfirmationSent('a@b.co')),
        screen: const CheckInboxScreen(),
        path: '/check-inbox',
        size: size,
      );

      testWidgets('P1-2: shows the title, message with the email, action', (
        tester,
      ) async {
        await pump(tester);

        expect(find.byType(BookletStatusFrame), findsOneWidget);
        expect(find.text('Check your inbox'), findsOneWidget);
        expect(
          find.text(
            'We sent a confirmation link to a@b.co. Open it, then sign in.',
          ),
          findsOneWidget,
        );
        expect(find.text('Back to sign in'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('P1-2: Back to sign in acknowledges the confirmation', (
        tester,
      ) async {
        final cubit = mockCubit(const AuthConfirmationSent('a@b.co'));
        await pumpAuthScreen(
          tester,
          cubit: cubit,
          screen: const CheckInboxScreen(),
          path: '/check-inbox',
          size: size,
        );

        await tester.tap(find.text('Back to sign in'));
        await tester.pump();

        verify(cubit.acknowledgeConfirmation).called(1);
      });
    });
  }
}
