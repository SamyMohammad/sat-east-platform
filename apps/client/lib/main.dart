import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:sat_east_client/app.dart';
import 'package:sat_east_client/core/analytics/analytics_factory.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/env/env.dart';
import 'package:sat_east_client/core/observability/error_reporter.dart';
import 'package:sat_east_client/core/observability/sentry_error_reporter.dart';
import 'package:sat_east_client/core/theme/theme_mode_cubit.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  if (Env.sentryDsn.isEmpty) {
    await _start(const NoopErrorReporter());
    return;
  }
  // Sentry wraps the whole start-up so early and uncaught errors are reported.
  await SentryFlutter.init(
    (options) => configureSentry(
      options,
      dsn: Env.sentryDsn,
      environment: Env.flavor.name,
    ),
    appRunner: () => _start(const SentryErrorReporter()),
  );
}

Future<void> _start(ErrorReporter errorReporter) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!Env.isConfigured) {
    throw StateError(
      'Missing Supabase config. Run with '
      '--dart-define-from-file=env/<flavor>.json',
    );
  }

  await Hive.initFlutter();
  final deviceBox = await Hive.openBox<String>('device');
  final settingsBox = await Hive.openBox<String>('settings');
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
  );
  final analytics = await createAnalytics(
    projectToken: Env.posthogKey,
    host: Env.posthogHost,
    reporter: errorReporter,
  );
  configureDependencies(
    errorReporter: errorReporter,
    analytics: analytics,
    deviceBox: deviceBox,
    settingsBox: settingsBox,
  );
  unawaited(getIt<AuthCubit>().start());

  runApp(App(auth: getIt<AuthCubit>(), themeMode: getIt<ThemeModeCubit>()));
}
