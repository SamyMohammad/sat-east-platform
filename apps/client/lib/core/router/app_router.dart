import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/router/placeholder_screen.dart';

abstract final class AppRoutes {
  static const home = '/';
}

GoRouter createRouter() => GoRouter(
  routes: [
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const PlaceholderScreen(),
    ),
  ],
);
