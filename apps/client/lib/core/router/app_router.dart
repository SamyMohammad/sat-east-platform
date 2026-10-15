import 'package:go_router/go_router.dart';

import 'package:sat_east_client/core/env/env.dart';
import 'package:sat_east_client/core/router/placeholder_screen.dart';
import 'package:sat_east_client/features/design_gallery/presentation/gallery_screen.dart';
import 'package:sat_east_client/shared/widgets/app_shell/app_shell.dart';
import 'package:sat_east_client/shared/widgets/app_shell/app_shell_destination.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const courses = '/courses';
  static const skills = '/skills';
  static const mockExams = '/mock-exams';
  static const profile = '/profile';
  static const gallery = '/gallery';
}

GoRouter createRouter({String? initialLocation, bool? includeGallery}) =>
    GoRouter(
      initialLocation: initialLocation,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => AppShell(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: (index) => shell.goBranch(index),
            child: shell,
          ),
          branches: [
            for (final destination in AppShellDestination.values)
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: _pathFor(destination),
                    builder: (context, state) => PlaceholderScreen(
                      title: destination == AppShellDestination.home
                          ? null
                          : destination.label,
                    ),
                  ),
                ],
              ),
          ],
        ),
        if (!Env.isProd && (includeGallery ?? true))
          GoRoute(
            path: AppRoutes.gallery,
            builder: (context, state) =>
                GalleryScreen(entryId: state.uri.queryParameters['entry']),
          ),
      ],
    );

String galleryLocation(String id) =>
    Uri(path: AppRoutes.gallery, queryParameters: {'entry': id}).toString();

String _pathFor(AppShellDestination destination) => switch (destination) {
  AppShellDestination.home => AppRoutes.home,
  AppShellDestination.courses => AppRoutes.courses,
  AppShellDestination.skills => AppRoutes.skills,
  AppShellDestination.mockExams => AppRoutes.mockExams,
  AppShellDestination.profile => AppRoutes.profile,
};
