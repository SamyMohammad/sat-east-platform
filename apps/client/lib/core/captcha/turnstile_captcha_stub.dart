import 'package:sat_east_client/core/captcha/captcha.dart';

/// Non-web builds have no captcha widget (Turnstile is web-only for the beta).
Captcha createCaptcha(String siteKey) => const NoCaptcha();
