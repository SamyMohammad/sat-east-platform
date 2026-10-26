import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/router/auth_refresh.dart';
import 'package:sat_east_client/core/theme/app_motion.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/core/theme/theme_mode_cubit.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_cubit.dart';

class App extends StatefulWidget {
  /// [auth] is the app-wide session cubit (`main.dart` passes it from DI).
  /// Without it there is no sign-in guard, which keeps shell tests simple.
  const App({super.key, this.auth, this.themeMode});

  final AuthCubit? auth;
  final ThemeModeCubit? themeMode;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  // Owned here so its stream subscription is cancelled with the app.
  late final GoRouterRefreshStream? _refresh = widget.auth == null
      ? null
      : GoRouterRefreshStream(widget.auth!.stream);
  late final GoRouter _router = createRouter(
    auth: widget.auth,
    refresh: _refresh,
  );
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Revocation check when the app comes back to the foreground.
    _lifecycle = AppLifecycleListener(
      onResume: () => widget.auth?.checkDevice(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _router.dispose();
    _refresh?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = widget.themeMode;
    final app = themeMode == null
        ? _materialApp(ThemeMode.system)
        : BlocBuilder<ThemeModeCubit, ThemeMode>(
            bloc: themeMode,
            builder: (context, mode) => _materialApp(mode),
          );
    final auth = widget.auth;
    return auth == null
        ? app
        : BlocProvider<AuthCubit>.value(value: auth, child: app);
  }

  Widget _materialApp(ThemeMode mode) => MaterialApp.router(
    title: 'SAT East',
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: mode,
    themeAnimationDuration: AppMotion.resolve(context, AppMotion.state),
    themeAnimationStyle: AppMotion.reduced(context)
        ? AnimationStyle.noAnimation
        : null,
    themeAnimationCurve: AppMotion.standard,
    routerConfig: _router,
  );
}
