import 'package:flutter/widgets.dart';
import 'package:sat_east_client/core/captcha/captcha.dart';

/// The captcha challenge for a form, or nothing when captcha is off.
class CaptchaSlot extends StatelessWidget {
  const CaptchaSlot({
    required this.captcha,
    required this.controller,
    super.key,
  });

  final Captcha captcha;
  final CaptchaController controller;

  @override
  Widget build(BuildContext context) =>
      captcha.enabled ? captcha.buildView(controller) : const SizedBox.shrink();
}
