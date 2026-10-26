import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_type.dart';

/// Deprecated shim: use App* tokens.
abstract final class BookletFonts {
  static const String sans = AppFonts.sans;
  static const String arabic = AppFonts.arabic;
}

/// Deprecated shim: use App* tokens.
abstract final class BookletType {
  static const double mathScale = AppType.mathScale;
  static TextTheme textTheme() => AppType.textTheme();
  static const TextStyle timer = AppType.timer;
  static const TextStyle arabic = AppType.arabic;
}
