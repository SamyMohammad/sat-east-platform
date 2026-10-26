import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:sat_east_client/core/theme/theme_mode_store.dart';

class ThemeModeCubit extends Cubit<ThemeMode> {
  ThemeModeCubit(this._store) : super(ThemeMode.system);

  final ThemeModeStore _store;
  int _revision = 0;

  void load() {
    _revision++;
    if (!isClosed) emit(_store.read());
  }

  Future<void> set(ThemeMode mode) async {
    final revision = ++_revision;
    final saved = await _store.write(mode);
    if (!isClosed && saved && revision == _revision) emit(mode);
  }
}
