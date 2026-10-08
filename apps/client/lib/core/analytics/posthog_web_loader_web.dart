import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Vendored posthog-js `array.no-external.js` (never loads scripts from
/// PostHog's CDN). Only fetched when `POSTHOG_KEY` is set.
const _scriptPath = 'vendor/posthog-js-1.434.13.js';

@JS('posthog')
external _PosthogJs? get _posthog;

extension type _PosthogJs(JSObject _) implements JSObject {
  external void init(String token, JSObject options);
}

/// Injects posthog-js and calls `posthog.init` with privacy-first options
/// (ADR-008): no autocapture, pageviews, session replay or surveys; person
/// profiles only after identify.
Future<void> loadPosthogWeb({
  required String projectToken,
  required String host,
}) async {
  if (_posthog == null) {
    final loaded = Completer<void>();
    final script = web.HTMLScriptElement()
      ..src = _scriptPath
      ..async = true
      ..onload = ((web.Event _) => loaded.complete()).toJS
      ..onerror = ((web.Event _) => loaded.completeError(
        StateError('posthog-js failed to load'),
      )).toJS;
    web.document.head!.appendChild(script);
    await loaded.future;
  }
  final options =
      <String, Object>{
            'api_host': host,
            'person_profiles': 'identified_only',
            'autocapture': false,
            'capture_pageview': false,
            'capture_pageleave': false,
            'disable_session_recording': true,
            'disable_surveys': true,
          }.jsify()!
          as JSObject;
  _posthog!.init(projectToken, options);
}
