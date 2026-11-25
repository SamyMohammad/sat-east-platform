import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/captcha/captcha.dart';

void main() {
  group('P3-1: CaptchaController', () {
    test('P3-1: starts with no token', () {
      final controller = CaptchaController();
      addTearDown(controller.dispose);

      expect(controller.token, isNull);
      expect(controller.hasToken, isFalse);
    });

    test('P3-1: a solved challenge stores the token and notifies', () {
      final controller = CaptchaController();
      addTearDown(controller.dispose);
      var notified = 0;
      controller
        ..addListener(() => notified++)
        ..setToken('tok');

      expect(controller.token, 'tok');
      expect(controller.hasToken, isTrue);
      expect(notified, 1);
    });

    test('P3-1: an empty token counts as no token', () {
      final controller = CaptchaController()..setToken('');
      addTearDown(controller.dispose);

      expect(controller.hasToken, isFalse);
    });

    test('P3-1: reset clears the token and re-runs the challenge', () {
      final controller = CaptchaController();
      addTearDown(controller.dispose);
      var viewResets = 0;
      controller
        ..bindView(() => viewResets++)
        ..setToken('tok')
        ..reset();

      expect(controller.token, isNull);
      expect(viewResets, 1);
    });

    test('P3-1: reset after the view unbinds only clears the token', () {
      final controller = CaptchaController();
      addTearDown(controller.dispose);
      var viewResets = 0;
      controller
        ..bindView(() => viewResets++)
        ..unbindView()
        ..setToken('tok')
        ..reset();

      expect(controller.token, isNull);
      expect(viewResets, 0);
    });

    test('P3-1: an expired or errored challenge clears the token', () {
      final controller = CaptchaController()..setToken('tok');
      addTearDown(controller.dispose);

      controller.setToken(null);

      expect(controller.hasToken, isFalse);
    });

    test('P3-1: NoCaptcha is disabled', () {
      expect(const NoCaptcha().enabled, isFalse);
    });
  });
}
