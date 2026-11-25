import 'package:flutter/material.dart';
import 'package:sat_east_client/core/captcha/captcha.dart';

/// A captcha whose view is a button: tapping it "solves" the challenge.
class FakeCaptcha implements Captcha {
  FakeCaptcha({this.token = 'tok'});

  final String token;
  int resets = 0;

  @override
  bool get enabled => true;

  @override
  Widget buildView(CaptchaController controller) =>
      _FakeCaptchaView(controller, token, () => resets++);
}

class _FakeCaptchaView extends StatefulWidget {
  const _FakeCaptchaView(this.controller, this.token, this.onReset);

  final CaptchaController controller;
  final String token;
  final VoidCallback onReset;

  @override
  State<_FakeCaptchaView> createState() => _FakeCaptchaViewState();
}

class _FakeCaptchaViewState extends State<_FakeCaptchaView> {
  @override
  void initState() {
    super.initState();
    widget.controller.bindView(widget.onReset);
  }

  @override
  void dispose() {
    widget.controller.unbindView();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => widget.controller.setToken(widget.token),
    child: const Text('Solve captcha'),
  );
}
