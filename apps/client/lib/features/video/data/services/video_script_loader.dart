import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

final _loads = <String, Future<void>>{};

/// Shares in-flight loads; a failed load can be retried without a page reload.
Future<void> loadVideoScript(String path) =>
    _loads.putIfAbsent(path, () => _load(path));

Future<void> _load(String path) async {
  final loaded = Completer<void>();
  final script = web.HTMLScriptElement()
    ..src = path
    ..async = true
    ..onload = ((web.Event _) {
      if (!loaded.isCompleted) loaded.complete();
    }).toJS
    ..onerror = ((web.Event _) {
      if (!loaded.isCompleted) {
        loaded.completeError(StateError('Video script unavailable'));
      }
    }).toJS;
  web.document.head!.appendChild(script);
  try {
    await loaded.future.timeout(const Duration(seconds: 20));
  } on Object {
    unawaited(_loads.remove(path));
    script.remove();
    rethrow;
  } finally {
    script
      ..onload = null
      ..onerror = null;
  }
}
