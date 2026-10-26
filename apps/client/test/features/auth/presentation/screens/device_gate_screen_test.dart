import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/auth/domain/entities/device.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_state.dart';
import 'package:sat_east_client/features/auth/presentation/screens/device_gate_screen.dart';
import 'package:sat_east_client/shared/widgets/app_banner.dart';

import 'auth_screen_harness.dart';

final _now = DateTime(2026, 10, 16, 15);

final _devices = [
  Device(
    id: 'd1',
    platform: 'web',
    label: 'Chrome on Windows',
    lastSeenAt: DateTime(2026, 10, 16, 9, 5),
  ),
  Device(
    id: 'd2',
    platform: 'android',
    lastSeenAt: DateTime(2026, 10, 15, 21, 30),
  ),
  Device(
    id: 'd3',
    platform: 'ios',
    label: 'iOS app',
    lastSeenAt: DateTime(2026, 10, 3, 8),
  ),
];

AuthDeviceGate _gate({int changesLeft = 1, bool removing = false}) =>
    AuthDeviceGate(
      devices: _devices,
      changesLeft: changesLeft,
      removing: removing,
    );

void main() {
  for (final (name, size) in viewports) {
    group('P1-2: DeviceGateScreen at $name', () {
      Future<MockAuthCubit> pump(WidgetTester tester, AuthState state) async {
        final cubit = mockCubit(state);
        await pumpAuthScreen(
          tester,
          cubit: cubit,
          screen: DeviceGateScreen(now: () => _now),
          path: '/devices',
          size: size,
        );
        return cubit;
      }

      Finder removeButton() => loadingButtonStartingWith('Remove');

      testWidgets('P1-2: shows title, body, devices and the change note', (
        tester,
      ) async {
        await pump(tester, _gate());

        expect(find.text("You're already using 3 devices"), findsOneWidget);
        expect(
          find.text(
            'You can use 3 devices. '
            'To continue on this device, remove one of them.',
          ),
          findsOneWidget,
        );
        expect(find.text('Chrome on Windows'), findsOneWidget);
        expect(find.text('iOS app'), findsOneWidget);
        expect(
          find.text(
            'Removing a device signs it out and uses 1 change. '
            'You have 1 change left this month.',
          ),
          findsOneWidget,
        );
        expect(find.text('Sign out'), findsOneWidget);
        expect(loadingButton('Sign out instead'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('P1-2: falls back to the platform when label is null', (
        tester,
      ) async {
        await pump(tester, _gate());

        expect(find.text('android'), findsOneWidget);
      });

      testWidgets('P1-2: pluralises the changes left', (tester) async {
        await pump(tester, _gate(changesLeft: 2));

        expect(
          find.textContaining('You have 2 changes left this month.'),
          findsOneWidget,
        );
      });

      testWidgets('P1-2: shows the last used time relative to now', (
        tester,
      ) async {
        await pump(tester, _gate());

        expect(find.text('Last used today 09:05'), findsOneWidget);
        expect(find.text('Last used yesterday 21:30'), findsOneWidget);
        expect(find.text('Last used 3 Oct'), findsOneWidget);
      });

      testWidgets('P1-2: remove is disabled until a device is chosen', (
        tester,
      ) async {
        await pump(tester, _gate());

        expect(buttonOf(tester, removeButton()).onPressed, isNull);
      });

      testWidgets('P1-2: choosing a device enables remove with its label', (
        tester,
      ) async {
        await pump(tester, _gate());

        await tester.tap(find.text('Chrome on Windows'));
        await tester.pump();

        expect(
          loadingButton('Remove Chrome on Windows and continue'),
          findsOneWidget,
        );
        expect(
          buttonOf(
            tester,
            loadingButton('Remove Chrome on Windows and continue'),
          ).onPressed,
          isNotNull,
        );
      });

      testWidgets('P1-2: remove asks for confirmation first', (tester) async {
        final cubit = await pump(tester, _gate());
        await tester.tap(find.text('Chrome on Windows'));
        await tester.pump();

        await tester.tap(removeButton());
        await tester.pumpAndSettle();

        expect(find.text('Remove Chrome on Windows?'), findsOneWidget);
        expect(find.text('It will be signed out there.'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Remove'), findsOneWidget);
        verifyNever(() => cubit.removeDevice(any()));
      });

      testWidgets('P1-2: Cancel closes the dialog without removing', (
        tester,
      ) async {
        final cubit = await pump(tester, _gate());
        await tester.tap(find.text('Chrome on Windows'));
        await tester.pump();
        await tester.tap(removeButton());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(find.text('Remove Chrome on Windows?'), findsNothing);
        verifyNever(() => cubit.removeDevice(any()));
      });

      testWidgets('P1-2: confirming Remove calls removeDevice with the id', (
        tester,
      ) async {
        final cubit = await pump(tester, _gate());
        await tester.tap(find.text('Chrome on Windows'));
        await tester.pump();
        await tester.tap(removeButton());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Remove'));
        await tester.pumpAndSettle();

        verify(() => cubit.removeDevice('d1')).called(1);
      });

      testWidgets('P1-2: only one device can be chosen at a time', (
        tester,
      ) async {
        final cubit = await pump(tester, _gate());
        await tester.tap(find.text('Chrome on Windows'));
        await tester.pump();
        expect(removeButton(), findsOneWidget);
        expect(find.text('iOS app').hitTestable(), findsOneWidget);
        expect(
          tester.getBottomLeft(find.text('iOS app')).dy,
          lessThan(tester.getTopLeft(removeButton()).dy),
        );
        await tester.tap(find.text('iOS app'));
        await tester.pump();
        expect(removeButton(), findsOneWidget);
        expect(
          loadingButton('Remove iOS app and continue'),
          findsOneWidget,
        );
        await tester.tap(removeButton());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Remove'));
        await tester.pumpAndSettle();

        verify(() => cubit.removeDevice('d3')).called(1);
        verifyNever(() => cubit.removeDevice('d1'));
      });

      testWidgets('P1-2: remove is loading while removing', (tester) async {
        await pump(tester, _gate(removing: true));

        expect(buttonOf(tester, removeButton()).isLoading, isTrue);
        expect(tester.takeException(), isNull);
      });

      testWidgets('P1-2: a gate error shows a banner', (tester) async {
        await pump(
          tester,
          AuthDeviceGate(
            devices: _devices,
            changesLeft: 1,
            error: const AppError(ErrorCodes.internal),
          ),
        );

        expect(find.byType(AppBanner), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('P1-2: no banner without a gate error', (tester) async {
        await pump(tester, _gate());

        expect(find.byType(AppBanner), findsNothing);
      });

      testWidgets('P1-2: both sign out buttons are disabled while removing', (
        tester,
      ) async {
        final cubit = await pump(tester, _gate(removing: true));

        await tester.tap(find.text('Sign out'), warnIfMissed: false);
        await tester.tap(
          loadingButton('Sign out instead'),
          warnIfMissed: false,
        );
        await tester.pump();

        verifyNever(cubit.signOut);
      });

      testWidgets('P1-2: the top Sign out calls signOut', (tester) async {
        final cubit = await pump(tester, _gate());

        await tester.tap(find.text('Sign out'));
        await tester.pump();

        verify(cubit.signOut).called(1);
      });

      testWidgets('P1-2: Sign out instead calls signOut', (tester) async {
        final cubit = await pump(tester, _gate());

        await tester.tap(loadingButton('Sign out instead'));
        await tester.pump();

        verify(cubit.signOut).called(1);
      });

      testWidgets('P1-2: with no changes left it shows the exhausted copy', (
        tester,
      ) async {
        await pump(tester, _gate(changesLeft: 0));

        expect(find.text('No changes left this month.'), findsOneWidget);
        expect(
          find.text(
            'Keep using one of your current devices, '
            'or contact your teacher.',
          ),
          findsOneWidget,
        );
        expect(find.text('Sign out'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('P1-2: with no changes left remove stays disabled', (
        tester,
      ) async {
        await pump(tester, _gate(changesLeft: 0));

        await tester.tap(find.text('Chrome on Windows'));
        await tester.pump();

        expect(buttonOf(tester, removeButton()).onPressed, isNull);
      });

      testWidgets('P1-2: with no changes left Sign out instead still works', (
        tester,
      ) async {
        final cubit = await pump(tester, _gate(changesLeft: 0));

        await tester.tap(loadingButton('Sign out instead'));
        await tester.pump();

        verify(cubit.signOut).called(1);
      });
    });
  }
}
