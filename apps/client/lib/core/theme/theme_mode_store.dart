import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:sat_east_client/core/observability/error_reporter.dart';

class ThemeModeStore {
  ThemeModeStore(this._box, this._reporter);

  static const _key = 'themeMode';
  final Box<String> _box;
  final ErrorReporter _reporter;

  ThemeMode read() {
    try {
      return switch (_box.get(_key)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } on Object catch (error, stack) {
      unawaited(
        _reporter.captureError(error, stack, hint: 'Read theme preference'),
      );
      return ThemeMode.system;
    }
  }

  Future<bool> write(ThemeMode mode) async {
    try {
      await _box.put(_key, mode.name);
      return true;
    } on Object catch (error, stack) {
      unawaited(
        _reporter.captureError(error, stack, hint: 'Save theme preference'),
      );
      return false;
    }
  }
}
