import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:sat_east_client/app.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/env/env.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!Env.isConfigured) {
    throw StateError(
      'Missing Supabase config. Run with '
      '--dart-define-from-file=env/<flavor>.json',
    );
  }

  await Hive.initFlutter();
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
  );
  configureDependencies();

  runApp(const App());
}
