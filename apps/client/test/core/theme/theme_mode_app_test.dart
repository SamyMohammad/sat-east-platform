import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/app.dart';
import 'package:sat_east_client/core/observability/error_reporter.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/theme/theme_mode_cubit.dart';
import 'package:sat_east_client/core/theme/theme_mode_store.dart';
import 'package:sat_east_client/features/skills/presentation/screens/skills_screen.dart';

import '../router/fake_skills_cubit.dart';

class _Box extends Mock implements Box<String> {}

void main() {
  setUp(registerFakeSkillsCubit);
  tearDown(unregisterFakeSkillsCubit);
  testWidgets('theme_switch_reduced_motion_shows_final_state_and_keeps_route', (
    tester,
  ) async {
    final box = _Box();
    when(() => box.put('themeMode', any())).thenAnswer((_) async {});
    final theme = ThemeModeCubit(
      ThemeModeStore(box, const NoopErrorReporter()),
    );
    addTearDown(theme.close);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: App(themeMode: theme),
      ),
    );
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.text('SAT East')))
      ..go(AppRoutes.skills);
    await tester.pumpAndSettle();
    await theme.set(ThemeMode.dark);
    // Two zero-duration frames: one for the cubit emit, one for the rebuilt
    // MaterialApp. No time passes, so any theme animation would still show.
    await tester.pump();
    await tester.pump();
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.skills);
    final context = tester.element(
      find.byType(SkillsView),
    );
    expect(Theme.of(context).brightness, Brightness.dark);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeAnimationDuration, Duration.zero);
    expect(app.themeAnimationStyle, AnimationStyle.noAnimation);
    expect(app.themeMode, ThemeMode.dark);
  });
}
