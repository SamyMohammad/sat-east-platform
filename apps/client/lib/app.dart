import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_cubit.dart';

class App extends StatefulWidget {
  /// [auth] is the app-wide session cubit (`main.dart` passes it from DI).
  /// Without it there is no sign-in guard, which keeps shell tests simple.
  const App({super.key, this.auth});

  final AuthCubit? auth;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final GoRouter _router = createRouter(auth: widget.auth);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp.router(
      title: 'SAT East',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: _router,
    );
    final auth = widget.auth;
    // One provider serves every auth screen.
    return auth == null
        ? app
        : BlocProvider<AuthCubit>.value(value: auth, child: app);
  }
}
