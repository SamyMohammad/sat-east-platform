import 'package:flutter/widgets.dart';

/// Holds the current captcha token for one form and lets the form reset the
/// challenge. UX only: GoTrue verifies the token server-side.
class CaptchaController extends ChangeNotifier {
  String? _token;
  VoidCallback? _resetView;

  /// The solved-challenge token, or null while unsolved/expired.
  String? get token => _token;

  bool get hasToken => _token != null && _token!.isNotEmpty;

  /// Called by the view when a challenge is solved (token) or expires/errors
  /// (null).
  void setToken(String? token) {
    if (_token == token) return;
    _token = token;
    notifyListeners();
  }

  /// The view registers how to re-run its challenge.
  // ignore: use_setters_to_change_properties
  void bindView(VoidCallback resetView) => _resetView = resetView;

  void unbindView() => _resetView = null;

  /// Tokens are single-use: clears the token and re-runs the challenge.
  void reset() {
    final hadToken = _token != null;
    _token = null;
    _resetView?.call();
    if (hadToken) notifyListeners();
  }
}

/// A captcha provider. Implementations render their own challenge view.
abstract interface class Captcha {
  /// False → no widget, no token, auth flows unchanged.
  bool get enabled;

  Widget buildView(CaptchaController controller);
}

/// Captcha off (no site key, or a platform without a widget).
class NoCaptcha implements Captcha {
  const NoCaptcha();

  @override
  bool get enabled => false;

  @override
  Widget buildView(CaptchaController controller) => const SizedBox.shrink();
}
