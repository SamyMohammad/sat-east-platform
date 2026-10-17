import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:sat_east_client/core/env/env.dart';
import 'package:sat_east_client/core/router/auth_refresh.dart';
import 'package:sat_east_client/core/router/placeholder_screen.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_state.dart';
import 'package:sat_east_client/features/auth/presentation/screens/check_inbox_screen.dart';
import 'package:sat_east_client/features/auth/presentation/screens/device_gate_screen.dart';
import 'package:sat_east_client/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:sat_east_client/features/auth/presentation/screens/sign_up_screen.dart';
import 'package:sat_east_client/features/course_map/presentation/screens/course_map_screen.dart';
import 'package:sat_east_client/features/design_gallery/presentation/gallery_screen.dart';
import 'package:sat_east_client/features/practice/presentation/screens/practice_screen.dart';
import 'package:sat_east_client/shared/widgets/app_shell/app_shell.dart';
import 'package:sat_east_client/shared/widgets/app_shell/app_shell_destination.dart';
import 'package:sat_east_client/shared/widgets/app_splash.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const courses = '/courses';
  static String topic(String id) => '/courses/topics/$id';
  static const skills = '/skills';
  static const mockExams = '/mock-exams';
  static const profile = '/profile';
  static const gallery = '/gallery';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const checkInbox = '/check-inbox';
  static const devices = '/devices';
}

/// [refresh] is owned (and disposed) by the caller; when omitted with [auth],
/// a stream-backed one is created and never disposed (tests only).
/// Auth screens read the [AuthCubit] from a `BlocProvider` above the app.
/// With [auth] set, the router redirects by session state; without it (tests)
/// there is no guard.
GoRouter createRouter({
  String? initialLocation,
  bool? includeGallery,
  AuthCubit? auth,
  Listenable? refresh,
}) {
  assert(refresh == null || auth != null, 'refresh requires auth');
  final galleryEnabled = !Env.isProd && (includeGallery ?? true);
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable:
        refresh ?? (auth == null ? null : GoRouterRefreshStream(auth.stream)),
    redirect: auth == null
        ? null
        : (context, state) =>
              _authRedirect(auth.state, state.uri.path, galleryEnabled),
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) {
          final appShell = AppShell(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: (index) => shell.goBranch(index),
            child: shell,
          );
          if (auth == null) return appShell;
          // AuthBusy is only emitted at boot/sign-in/sign-up, never while on
          // shell paths; emitting it while signed in would unmount the shell
          // and reset the branch stacks.
          return BlocSelector<AuthCubit, AuthState, bool>(
            bloc: auth,
            selector: (s) => s is AuthUnknown || s is AuthBusy,
            builder: (_, busy) => busy ? const AppSplash() : appShell,
          );
        },
        branches: [
          for (final destination in AppShellDestination.values)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: _pathFor(destination),
                  builder: (context, state) => switch (destination) {
                    AppShellDestination.courses => const CourseMapScreen(),
                    AppShellDestination.home => const PlaceholderScreen(),
                    _ => PlaceholderScreen(title: destination.label),
                  },
                  routes: [
                    if (destination == AppShellDestination.courses)
                      GoRoute(
                        path: 'topics/:topicId',
                        builder: (context, state) => PracticeScreen(
                          topicId: state.pathParameters['topicId']!,
                          title: switch (state.extra) {
                            final String t => t,
                            _ => null,
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
        ],
      ),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: AppRoutes.checkInbox,
        builder: (context, state) => const CheckInboxScreen(),
      ),
      GoRoute(
        path: AppRoutes.devices,
        builder: (context, state) => const DeviceGateScreen(),
      ),
      if (galleryEnabled)
        GoRoute(
          path: AppRoutes.gallery,
          builder: (context, state) =>
              GalleryScreen(entryId: state.uri.queryParameters['entry']),
        ),
    ],
  );
}

const _signedOutPaths = <String>{AppRoutes.signIn, AppRoutes.signUp};

/// Returns the location to move to, or null to stay. Never loops: every
/// target is a fixed point of the same function for that state.
String? _authRedirect(AuthState state, String path, bool galleryEnabled) {
  if (galleryEnabled && path == AppRoutes.gallery) return null;
  return switch (state) {
    AuthUnknown() || AuthBusy() => null,
    AuthSignedOut() => _signedOutPaths.contains(path) ? null : AppRoutes.signIn,
    AuthConfirmationSent() =>
      path == AppRoutes.checkInbox ? null : AppRoutes.checkInbox,
    AuthDeviceGate() => path == AppRoutes.devices ? null : AppRoutes.devices,
    AuthSignedIn() =>
      _signedOutPaths.contains(path) ||
              path == AppRoutes.checkInbox ||
              path == AppRoutes.devices
          ? AppRoutes.home
          : null,
  };
}

String galleryLocation(String id) =>
    Uri(path: AppRoutes.gallery, queryParameters: {'entry': id}).toString();

String _pathFor(AppShellDestination destination) => switch (destination) {
  AppShellDestination.home => AppRoutes.home,
  AppShellDestination.courses => AppRoutes.courses,
  AppShellDestination.skills => AppRoutes.skills,
  AppShellDestination.mockExams => AppRoutes.mockExams,
  AppShellDestination.profile => AppRoutes.profile,
};
