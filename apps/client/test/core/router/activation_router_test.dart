import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/router/placeholder_screen.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/activation/domain/entities/activation_result.dart';
import 'package:sat_east_client/features/activation/domain/repositories/activation_repository.dart';
import 'package:sat_east_client/features/activation/presentation/cubit/activation_cubit.dart';
import 'package:sat_east_client/features/activation/presentation/screens/activate_screen.dart';
import 'package:sat_east_client/features/auth/domain/entities/app_user.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_state.dart';
import 'package:sat_east_client/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:sat_east_client/features/course_map/domain/entities/course_map.dart';
import 'package:sat_east_client/features/course_map/domain/repositories/course_map_repository.dart';
import 'package:sat_east_client/features/course_map/presentation/cubit/course_map_cubit.dart';
import 'package:sat_east_client/features/course_map/presentation/screens/course_map_screen.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

import '../../features/activation/activation_fixtures.dart';
import '../../features/auth/presentation/screens/auth_screen_harness.dart'
    as auth_screens;

const _signedIn = AuthSignedIn(AppUser(id: 'student', email: 's@example.com'));
const _map = CourseMap(
  courseId: 'course-1',
  slug: 'sat-math',
  title: 'SAT Math',
  continueTopic: null,
  units: [
    MapUnit(
      title: 'Algebra',
      topics: [
        MapTopic(
          id: 'topic-1',
          slug: 'linear',
          title: 'Linear equations',
          sortLabel: '1.1',
          isFreePreview: false,
          status: TopicStatus.open,
          lockReason: null,
        ),
      ],
    ),
  ],
);

class _MapRepository implements CourseMapRepository {
  bool enrolled = false;
  int loads = 0;

  @override
  Future<Result<CourseMap>> getCourseMap({String? slug}) async {
    loads++;
    return enrolled
        ? const Success(_map)
        : const Failure(AppError(ErrorCodes.notEnrolled));
  }
}

class _ActivationRepository implements ActivationRepository {
  _ActivationRepository(this.maps);

  final _MapRepository maps;
  int redemptions = 0;

  @override
  Future<Result<ActivationResult>> redeem(
    String code,
    DateTime testDate,
  ) async {
    redemptions++;
    maps.enrolled = true;
    return Success(activationResult);
  }
}

Future<void> _pumpRouter(
  WidgetTester tester,
  GoRouter router,
  AuthCubit auth,
) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    BlocProvider<AuthCubit>.value(
      value: auth,
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('S-10: signed-in home keeps its placeholder without map DI', (
    tester,
  ) async {
    expect(getIt.isRegistered<CourseMapCubit>(), isFalse);
    final auth = auth_screens.mockCubit(_signedIn);
    final refresh = ValueNotifier(0);
    addTearDown(refresh.dispose);
    final router = createRouter(
      initialLocation: AppRoutes.home,
      auth: auth,
      refresh: refresh,
    );
    addTearDown(router.dispose);

    await _pumpRouter(tester, router, auth);

    expect(router.routeInformationProvider.value.uri.path, AppRoutes.home);
    expect(find.byType(PlaceholderScreen), findsOneWidget);
    expect(find.byType(CourseMapScreen), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('S-10: signed-out activation link redirects to sign in', (
    tester,
  ) async {
    final auth = auth_screens.mockCubit(const AuthSignedOut());
    final refresh = ValueNotifier(0);
    addTearDown(refresh.dispose);
    final router = createRouter(
      initialLocation: AppRoutes.activate,
      auth: auth,
      refresh: refresh,
    );
    addTearDown(router.dispose);

    await _pumpRouter(tester, router, auth);

    expect(router.routeInformationProvider.value.uri.path, AppRoutes.signIn);
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.byType(ActivateScreen), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'S-10: successful activation loads a fresh enrolled map at /courses',
    (tester) async {
      final maps = _MapRepository();
      final activation = _ActivationRepository(maps);
      var createdMaps = 0;
      getIt
        ..registerFactory<CourseMapCubit>(() {
          createdMaps++;
          return CourseMapCubit(maps);
        })
        ..registerFactory<ActivationCubit>(() => ActivationCubit(activation));
      addTearDown(() async {
        await getIt.unregister<CourseMapCubit>();
        await getIt.unregister<ActivationCubit>();
      });
      final auth = auth_screens.mockCubit(_signedIn);
      final refresh = ValueNotifier(0);
      addTearDown(refresh.dispose);
      final router = createRouter(
        initialLocation: AppRoutes.courses,
        auth: auth,
        refresh: refresh,
      );
      addTearDown(router.dispose);
      await _pumpRouter(tester, router, auth);
      expect(find.text('No course yet'), findsOneWidget);
      expect(maps.loads, 1);

      await tester.tap(find.text('Enter activation code'));
      await tester.pumpAndSettle();
      expect(find.byType(ActivateScreen), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Activation code'),
        ' ab12-cd34 ef56 ',
      );
      await tester.tap(find.widgetWithText(TextFormField, 'Test date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(LoadingButton, 'Activate'));
      await tester.pumpAndSettle();

      expect(activation.redemptions, 1);
      expect(router.routeInformationProvider.value.uri.path, AppRoutes.courses);
      expect(find.byType(CourseMapScreen), findsOneWidget);
      expect(find.text('SAT Math'), findsOneWidget);
      expect(find.text('Linear equations'), findsOneWidget);
      expect(find.text('No course yet'), findsNothing);
      expect(createdMaps, greaterThan(1));
      expect(maps.loads, greaterThan(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
