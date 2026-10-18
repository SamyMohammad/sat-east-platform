import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/activation/presentation/cubit/activation_cubit.dart';
import 'package:sat_east_client/features/activation/presentation/cubit/activation_state.dart';
import 'package:sat_east_client/features/activation/presentation/screens/activate_screen.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

import '../activation_fixtures.dart';

class _MockCubit extends MockCubit<ActivationState>
    implements ActivationCubit {}

final _today = DateTime(2026, 10, 18);

Finder get _code => find.widgetWithText(TextFormField, 'Activation code');
Finder get _date => find.widgetWithText(TextFormField, 'Test date');
Finder get _activate => find.widgetWithText(LoadingButton, 'Activate');

Future<GoRouter> _pump(
  WidgetTester tester,
  ActivationCubit cubit, {
  double width = 360,
  DateTime? now,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final clock = now ?? _today;
  final router = GoRouter(
    initialLocation: '/activate',
    routes: [
      GoRoute(
        path: '/activate',
        builder: (context, state) => BlocProvider<ActivationCubit>.value(
          value: cubit,
          child: ActivateView(now: () => clock),
        ),
      ),
      GoRoute(
        path: AppRoutes.courses,
        builder: (context, state) => const Scaffold(body: Text('course map')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return router;
}

Future<void> _pickToday(WidgetTester tester) async {
  await tester.tap(_date);
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [360.0, 1280.0]) {
    testWidgets('S-10: activation form fits $width', (tester) async {
      final cubit = ActivationCubit(FakeActivationRepository());
      addTearDown(cubit.close);
      await _pump(tester, cubit, width: width);

      expect(find.text('Enter activation code'), findsOneWidget);
      expect(_code, findsOneWidget);
      expect(_date, findsOneWidget);
      expect(_activate, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('S-10: missing code and date never redeem', (tester) async {
    final repository = FakeActivationRepository();
    final cubit = ActivationCubit(repository);
    addTearDown(cubit.close);
    await _pump(tester, cubit);

    await tester.tap(_activate);
    await tester.pumpAndSettle();

    expect(repository.calls, isEmpty);
  });

  testWidgets('S-10: whitespace-only code never redeems', (tester) async {
    final repository = FakeActivationRepository();
    final cubit = ActivationCubit(repository);
    addTearDown(cubit.close);
    await _pump(tester, cubit);
    await tester.enterText(_code, '   ');
    await _pickToday(tester);

    await tester.tap(_activate);
    await tester.pumpAndSettle();

    expect(repository.calls, isEmpty);
  });

  testWidgets('S-10: code without date never redeems', (tester) async {
    final repository = FakeActivationRepository();
    final cubit = ActivationCubit(repository);
    addTearDown(cubit.close);
    await _pump(tester, cubit);
    await tester.enterText(_code, 'AB12CD34EF56');

    await tester.tap(_activate);
    await tester.pumpAndSettle();

    expect(repository.calls, isEmpty);
  });

  for (final now in [
    DateTime(2026, 10, 18, 23, 59),
    DateTime(2028, 2, 29, 2, 30),
  ]) {
    testWidgets('S-10: actual picker has calendar bounds at $now', (
      tester,
    ) async {
      final cubit = ActivationCubit(FakeActivationRepository());
      addTearDown(cubit.close);
      await _pump(tester, cubit, now: now);

      await tester.tap(_date);
      await tester.pumpAndSettle();

      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      final today = DateTime(now.year, now.month, now.day);
      expect(picker.firstDate, today);
      expect(picker.lastDate, DateTime(now.year, now.month, now.day + 548));
      expect(picker.initialDate, today);
    });
  }

  for (final (code, message) in [
    (ErrorCodes.codeInvalid, "That code isn't valid. Check it and try again."),
    (ErrorCodes.codeUsed, 'That code has already been used.'),
    (ErrorCodes.alreadyEnrolled, "You're already enrolled in this course."),
    (ErrorCodes.rateLimited, 'Too many tries. Wait a minute and try again.'),
    (ErrorCodes.invalidInput, 'Pick a test date in the next 18 months.'),
    (ErrorCodes.network, 'Check your connection and try again.'),
    (ErrorCodes.internal, 'Something went wrong. Try again.'),
  ]) {
    testWidgets('S-10: $code shows safe English copy', (tester) async {
      final cubit = _MockCubit();
      whenListen(
        cubit,
        const Stream<ActivationState>.empty(),
        initialState: ActivationFailed(AppError(code, 'private details')),
      );
      await _pump(tester, cubit);

      expect(find.text(message), findsOneWidget);
      expect(find.textContaining('private details'), findsNothing);
      if (code == ErrorCodes.invalidInput) {
        final input = find.descendant(
          of: _date,
          matching: find.byType(TextField),
        );
        expect(
          tester.widget<TextField>(input).decoration?.errorText,
          message,
        );
      }
    });
  }

  testWidgets('S-10: submitting disables the button and both inputs', (
    tester,
  ) async {
    final cubit = _MockCubit();
    whenListen(
      cubit,
      const Stream<ActivationState>.empty(),
      initialState: const ActivationSubmitting(),
    );
    await _pump(tester, cubit);

    expect(tester.widget<LoadingButton>(_activate).isLoading, isTrue);
    expect(tester.widget<TextFormField>(_code).enabled, isFalse);
    expect(tester.widget<TextFormField>(_date).enabled, isFalse);
    final button = find.descendant(
      of: _activate,
      matching: find.byType(FilledButton),
    );
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
  });

  testWidgets('S-10: successful redeem navigates to the courses route', (
    tester,
  ) async {
    final repository = FakeActivationRepository();
    final cubit = ActivationCubit(repository);
    addTearDown(cubit.close);
    final router = await _pump(tester, cubit);
    await tester.enterText(_code, ' ab12-cd34 ef56 ');
    await _pickToday(tester);

    await tester.tap(_activate);
    await tester.pumpAndSettle();

    expect(repository.calls, [(' ab12-cd34 ef56 ', _today)]);
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.courses);
    expect(find.text('course map'), findsOneWidget);
  });
}
