import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/auth/domain/entities/device.dart';
import 'package:sat_east_client/features/auth/domain/entities/my_enrollment.dart';
import 'package:sat_east_client/features/auth/domain/entities/my_profile.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/account_cubit.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/account_state.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_state.dart';
import 'package:sat_east_client/features/auth/presentation/screens/account_screen.dart';
import 'package:sat_east_client/shared/widgets/booklet_dialog.dart';

import 'auth_screen_harness.dart';

class _Account extends MockCubit<AccountState> implements AccountCubit {}

const _profile = MyProfile(fullName: 'Student Name', email: 's@example.com');
const _current = Device(id: 'current', label: 'Laptop', isCurrent: true);
final _other = Device(
  id: 'other',
  label: 'Phone',
  platform: 'android',
  lastSeenAt: DateTime(2026, 10, 18, 9),
);

void main() {
  late _Account account;
  late MockAuthCubit auth;
  setUp(() {
    account = _Account();
    auth = mockCubit(const AuthSignedOut());
    when(account.load).thenAnswer((_) async {});
    when(() => account.changePassword(any())).thenAnswer((_) async {});
    when(() => account.removeDevice(any())).thenAnswer((_) async {});
  });

  Future<void> pump(
    WidgetTester tester,
    Size size,
    AccountState state, {
    Stream<AccountState> states = const Stream<AccountState>.empty(),
  }) async {
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    whenListen(
      account,
      states,
      initialState: state,
    );
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AccountCubit>.value(value: account),
          BlocProvider<AuthCubit>.value(value: auth),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: AccountView(now: () => DateTime(2026, 10, 18, 12)),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  for (final (name, size) in viewports) {
    testWidgets('AUTH-02: account shows enrollment dates at $name', (
      tester,
    ) async {
      final target = DateTime(2027, 3, 15);
      final expires = DateTime.utc(2027, 3, 30, 23, 30);
      await pump(
        tester,
        size,
        AccountLoaded(
          _profile,
          const [],
          2,
          enrollments: [
            MyEnrollment(
              courseTitle: 'SAT Math',
              targetTestDate: target,
              expiresAt: expires,
              isExpired: false,
            ),
          ],
        ),
      );
      final localizations = MaterialLocalizations.of(
        tester.element(find.byType(AccountView)),
      );
      final expectedTarget = localizations.formatShortDate(target);
      final expectedExpiry = localizations.formatShortDate(expires.toLocal());

      await tester.ensureVisible(find.text('Course'));
      expect(find.text('Course'), findsOneWidget);
      expect(find.text('SAT Math'), findsOneWidget);
      expect(find.text('Test date'), findsOneWidget);
      expect(find.text(expectedTarget), findsOneWidget);
      expect(expectedTarget, contains(target.year.toString()));
      expect(find.text('Access until'), findsOneWidget);
      expect(find.text(expectedExpiry), findsOneWidget);
      expect(find.text('Access ended'), findsNothing);
      expect(
        find.text('Contact your teacher to change your test date.'),
        findsOneWidget,
      );
      for (final field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        expect(
          field.controller?.text,
          isNot(anyOf('SAT Math', expectedTarget, expectedExpiry)),
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('AUTH-02: expired enrollment without a date at $name', (
      tester,
    ) async {
      final expires = DateTime.utc(2026, 10, 17);
      await pump(
        tester,
        size,
        AccountLoaded(
          _profile,
          const [],
          2,
          enrollments: [
            MyEnrollment(
              courseTitle: 'EST Math',
              targetTestDate: null,
              expiresAt: expires,
              isExpired: true,
            ),
          ],
        ),
      );
      final localizations = MaterialLocalizations.of(
        tester.element(find.byType(AccountView)),
      );

      await tester.ensureVisible(find.text('Course'));
      expect(find.text('EST Math'), findsOneWidget);
      expect(find.text('Access ended'), findsOneWidget);
      expect(
        find.text(localizations.formatShortDate(expires.toLocal())),
        findsOneWidget,
      );
      expect(find.text('Test date'), findsNothing);
      expect(find.text('Access until'), findsNothing);
      expect(
        find.text('Contact your teacher to change your test date.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('AUTH-02: all enrollments share one course section at $name', (
      tester,
    ) async {
      await pump(
        tester,
        size,
        AccountLoaded(
          _profile,
          const [],
          2,
          enrollments: [
            MyEnrollment(
              courseTitle: 'SAT Math',
              targetTestDate: DateTime(2027, 3, 15),
              expiresAt: DateTime.utc(2027, 3, 30),
              isExpired: false,
            ),
            MyEnrollment(
              courseTitle: 'EST Math',
              targetTestDate: null,
              expiresAt: DateTime.utc(2027, 4, 30),
              isExpired: true,
            ),
          ],
        ),
      );

      await tester.ensureVisible(find.text('Course'));
      expect(find.text('Course'), findsOneWidget);
      expect(find.text('SAT Math'), findsOneWidget);
      expect(find.text('EST Math'), findsOneWidget);
      expect(find.text('Test date'), findsOneWidget);
      expect(find.text('Access until'), findsOneWidget);
      expect(find.text('Access ended'), findsOneWidget);
      expect(
        find.text('Contact your teacher to change your test date.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('AUTH-02: no enrollments hides the course section at $name', (
      tester,
    ) async {
      await pump(tester, size, AccountLoaded(_profile, const [], 2));

      expect(find.text('Course'), findsNothing);
      expect(find.text('Test date'), findsNothing);
      expect(find.text('Access until'), findsNothing);
      expect(find.text('Access ended'), findsNothing);
      expect(
        find.text('Contact your teacher to change your test date.'),
        findsNothing,
      );
      expect(find.text('Student Name'), findsOneWidget);
    });

    testWidgets('S-34: saved password clears both fields at $name', (
      tester,
    ) async {
      final updates = StreamController<AccountState>();
      addTearDown(updates.close);
      await pump(
        tester,
        size,
        AccountLoaded(_profile, const [], 2),
        states: updates.stream,
      );
      await tester.enterText(find.byType(TextField).at(0), 'Password1');
      await tester.enterText(find.byType(TextField).at(1), 'Password1');
      updates.add(AccountLoaded(_profile, const [], 2, passwordSaved: true));
      await tester.pump();
      for (final field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        expect(field.controller?.text, isEmpty);
      }
      expect(find.text('Password saved.'), findsOneWidget);
    });
    testWidgets('S-34: profile is read-only at $name', (tester) async {
      await pump(tester, size, AccountLoaded(_profile, [_current, _other], 2));
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Student Name'), findsOneWidget);
      expect(find.text('s@example.com'), findsOneWidget);
      expect(
        find.text('Contact your teacher to change your name.'),
        findsOneWidget,
      );
      for (final field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        expect(
          field.controller?.text,
          isNot(anyOf('Student Name', 's@example.com')),
        );
      }
      expect(tester.takeException(), isNull);
    });
    testWidgets('AUTH-04: current device has no removal at $name', (
      tester,
    ) async {
      await pump(tester, size, AccountLoaded(_profile, [_current, _other], 2));
      await tester.ensureVisible(find.text('This device'));
      expect(find.byKey(const ValueKey('remove-device-current')), findsNothing);
      final remove = find.byKey(const ValueKey('remove-device-other'));
      await tester.ensureVisible(remove);
      expect(buttonOf(tester, remove).onPressed, isNotNull);
      expect(find.text('2 changes left this month'), findsOneWidget);
      expect(find.text('Last used today 09:00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('AUTH-04: zero allowance disables remove at $name', (
      tester,
    ) async {
      await pump(tester, size, AccountLoaded(_profile, [_other], 0));
      final remove = find.byKey(const ValueKey('remove-device-other'));
      await tester.ensureVisible(remove);
      expect(buttonOf(tester, remove).onPressed, isNull);
      expect(find.text('No changes left this month'), findsOneWidget);
      verifyNever(() => account.removeDevice(any()));
    });
    for (final confirm in [false, true]) {
      testWidgets('AUTH-04: removal confirmation $confirm at $name', (
        tester,
      ) async {
        await pump(tester, size, AccountLoaded(_profile, [_other], 2));
        final remove = find.byKey(const ValueKey('remove-device-other'));
        await tester.ensureVisible(remove);
        await tester.tap(remove);
        await tester.pumpAndSettle();
        expect(find.text('Remove this device?'), findsOneWidget);
        verifyNever(() => account.removeDevice(any()));
        await tester.tap(
          find.descendant(
            of: find.byType(BookletDialog),
            matching: find.text(confirm ? 'Remove' : 'Cancel'),
          ),
        );
        await tester.pumpAndSettle();
        if (confirm) {
          verify(() => account.removeDevice('other')).called(1);
        } else {
          verifyNever(() => account.removeDevice(any()));
        }
      });
    }
    testWidgets('S-34: password validation and submission at $name', (
      tester,
    ) async {
      await pump(tester, size, AccountLoaded(_profile, const [], 2));
      final save = loadingButton('Save password');
      expect(buttonOf(tester, save).onPressed, isNull);
      await tester.enterText(find.byType(TextField).at(0), 'Password1');
      await tester.enterText(find.byType(TextField).at(1), 'Different1');
      await tester.pump();
      expect(buttonOf(tester, save).onPressed, isNull);
      await tester.enterText(find.byType(TextField).at(1), 'Password1');
      await tester.pump();
      await tester.ensureVisible(save);
      await tester.tap(save);
      verify(() => account.changePassword('Password1')).called(1);
    });
    testWidgets('S-34: busy disables account actions at $name', (tester) async {
      await pump(
        tester,
        size,
        AccountLoaded(_profile, [_other], 2, busy: true),
      );
      expect(
        buttonOf(tester, loadingButton('Save password')).isLoading,
        isTrue,
      );
      final remove = find.byKey(const ValueKey('remove-device-other'));
      await tester.ensureVisible(remove);
      expect(buttonOf(tester, remove).onPressed, isNull);
    });
    testWidgets('S-34: loading and error retry at $name', (tester) async {
      await pump(tester, size, const AccountLoading());
      expect(find.byType(TextField), findsNothing);
      await pump(
        tester,
        size,
        const AccountError(AppError(ErrorCodes.network, 'raw failure')),
      );
      expect(
        find.text('No connection. Check your internet and try again.'),
        findsOneWidget,
      );
      expect(find.text('raw failure'), findsNothing);
      await tester.tap(loadingButton('Retry'));
      verify(account.load).called(1);
    });
    testWidgets('AUTH-04: empty devices are explicit at $name', (tester) async {
      await pump(tester, size, AccountLoaded(_profile, const [], 2));
      await tester.ensureVisible(find.text('No devices to show.'));
      expect(find.text('No devices to show.'), findsOneWidget);
    });
    testWidgets('S-34: password success copy at $name', (tester) async {
      await pump(
        tester,
        size,
        AccountLoaded(_profile, const [], 2, passwordSaved: true),
      );
      expect(find.text('Password saved.'), findsOneWidget);
    });
    testWidgets('S-34: sign out delegates to app auth at $name', (
      tester,
    ) async {
      await pump(tester, size, AccountLoaded(_profile, const [], 2));
      final signOut = loadingButton('Sign out');
      await tester.ensureVisible(signOut);
      await tester.tap(signOut);
      verify(auth.signOut).called(1);
    });
  }
}
