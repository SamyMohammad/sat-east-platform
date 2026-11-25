import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/material.dart';
import 'package:sat_east_client/core/captcha/captcha.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/core/web/script_loader.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';
import 'package:web/web.dart' as web;

/// Cloudflare's loader. Origin must be allowed by `script-src`/`frame-src`
/// in `apps/client/web/_headers`.
const _scriptUrl =
    'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit';

@JS('turnstile')
external _Turnstile? get _turnstile;

extension type _Turnstile(JSObject _) implements JSObject {
  external String render(web.HTMLElement container, JSObject options);
  external void reset(String widgetId);
  external void remove(String widgetId);
}

/// Empty site key → captcha off.
Captcha createCaptcha(String siteKey) =>
    siteKey.isEmpty ? const NoCaptcha() : TurnstileCaptcha(siteKey);

class TurnstileCaptcha implements Captcha {
  const TurnstileCaptcha(this.siteKey);

  final String siteKey;

  @override
  bool get enabled => true;

  @override
  Widget buildView(CaptchaController controller) =>
      _TurnstileView(siteKey: siteKey, controller: controller);
}

class _TurnstileView extends StatefulWidget {
  const _TurnstileView({required this.siteKey, required this.controller});

  final String siteKey;
  final CaptchaController controller;

  @override
  State<_TurnstileView> createState() => _TurnstileViewState();
}

enum _Load { loading, ready, failed }

class _TurnstileViewState extends State<_TurnstileView> {
  // Turnstile's "normal" widget size.
  static const _width = 300.0;
  static const _height = 65.0;

  _Load _load = _Load.loading;
  String? _widgetId;
  Timer? _renderTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.bindView(_reset);
    unawaited(_loadScript());
  }

  Future<void> _loadScript() async {
    setState(() => _load = _Load.loading);
    try {
      await loadScript(_scriptUrl);
      if (_turnstile == null) throw StateError('Turnstile unavailable');
      if (mounted) setState(() => _load = _Load.ready);
    } on Object {
      if (mounted) setState(() => _load = _Load.failed);
    }
  }

  void _reset() {
    final id = _widgetId;
    final api = _turnstile;
    if (id == null || api == null) return;
    try {
      api.reset(id);
    } on Object {
      // The widget is gone; the next build renders a new one.
    }
  }

  void _render(Object element) {
    // Flutter calls this before the element is attached to the DOM.
    _renderTimer?.cancel();
    _renderTimer = Timer(const Duration(milliseconds: 50), () {
      final api = _turnstile;
      if (!mounted || api == null) return;
      final controller = widget.controller;
      final options = JSObject()
        ..['sitekey'] = widget.siteKey.toJS
        ..['theme'] = 'auto'.toJS
        ..['callback'] = ((JSString token) {
          controller.setToken(token.toDart);
        }).toJS
        ..['expired-callback'] = (() {
          controller.setToken(null);
        }).toJS
        ..['timeout-callback'] = (() {
          controller.setToken(null);
        }).toJS
        ..['error-callback'] = ((JSAny? _) {
          controller.setToken(null);
          // Handled: stops Turnstile logging a console error.
          return true.toJS;
        }).toJS;
      try {
        _widgetId = api.render(element as web.HTMLElement, options);
      } on Object {
        if (mounted) setState(() => _load = _Load.failed);
      }
    });
  }

  @override
  void dispose() {
    _renderTimer?.cancel();
    widget.controller.unbindView();
    final id = _widgetId;
    final api = _turnstile;
    if (id != null && api != null) {
      try {
        api.remove(id);
      } on Object {
        // Already removed.
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => switch (_load) {
    _Load.loading => const SizedBox(height: _height),
    _Load.ready => SizedBox(
      width: _width,
      height: _height,
      child: HtmlElementView.fromTagName(
        tagName: 'div',
        onElementCreated: _render,
      ),
    ),
    _Load.failed => Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpace.s2,
      children: [
        const Text("The security check didn't load."),
        LoadingButton(
          label: 'Try again',
          variant: AppButtonVariant.tertiary,
          onPressed: () => unawaited(_loadScript()),
        ),
      ],
    ),
  };
}
