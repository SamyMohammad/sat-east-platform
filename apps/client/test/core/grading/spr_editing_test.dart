import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/grading/spr_editing.dart';

void main() {
  group('applySprKey', () {
    test('F-4: digits append', () {
      expect(applySprKey('1', SprKey.two), (text: '12', hint: null));
      expect(applySprKey('', SprKey.digit(7)), (text: '7', hint: null));
    });

    test('F-4: minus toggles at the front and inserts ASCII hyphen', () {
      expect(applySprKey('3/4', SprKey.minus), (text: '-3/4', hint: null));
      expect(applySprKey('-3/4', SprKey.minus), (text: '3/4', hint: null));
      expect(applySprKey('', SprKey.minus).text, '-');
      expect(applySprKey('', SprKey.minus).text.codeUnitAt(0), 0x2D);
    });

    test('F-4: a second slash is refused with a hint', () {
      expect(
        applySprKey('3/4', SprKey.slash),
        (text: '3/4', hint: SprKeyHint.secondSlash),
      );
    });

    test('F-4: a second dot is refused with a hint', () {
      expect(
        applySprKey('1.5', SprKey.dot),
        (text: '1.5', hint: SprKeyHint.secondDot),
      );
    });

    test('F-4: slash and dot cannot be mixed', () {
      expect(
        applySprKey('1.5', SprKey.slash),
        (text: '1.5', hint: SprKeyHint.slashAndDot),
      );
      expect(
        applySprKey('3/', SprKey.dot),
        (text: '3/', hint: SprKeyHint.slashAndDot),
      );
    });

    test('F-4: backspace removes the last character, no-op when empty', () {
      expect(applySprKey('-3', SprKey.backspace), (text: '-', hint: null));
      expect(applySprKey('', SprKey.backspace), (text: '', hint: null));
    });

    test('F-4: input stops at sprInputMaxChars', () {
      final full = '1' * sprInputMaxChars;
      expect(applySprKey(full, SprKey.one), (text: full, hint: null));
    });
  });

  group('normalizeSprDigits', () {
    test('F-4: Arabic-Indic and Persian digits become ASCII', () {
      expect(normalizeSprDigits('٣/٤'), '3/4');
      expect(normalizeSprDigits('۱.۵'), '1.5');
    });

    test('F-4: Arabic decimal separator and U+2212 minus become ASCII', () {
      expect(normalizeSprDigits('١٫٥'), '1.5');
      expect(normalizeSprDigits('−3'), '-3');
    });

    test('F-4: ASCII input is unchanged', () {
      expect(normalizeSprDigits('-12.5 x'), '-12.5 x');
    });
  });

  group('sprPreviewTex', () {
    test('F-4: fractions render as dfrac, as typed (not reduced)', () {
      expect(sprPreviewTex('-3/4'), r'-\dfrac{3}{4}');
      expect(sprPreviewTex('2/4'), r'\dfrac{2}{4}');
    });

    test('F-4: decimals and integers render as typed', () {
      expect(sprPreviewTex('1.5'), '1.5');
      expect(sprPreviewTex('.5'), '.5');
      expect(sprPreviewTex('12'), '12');
    });

    test('F-4: no preview until the input is a number', () {
      expect(sprPreviewTex(''), isNull);
      expect(sprPreviewTex('-'), isNull);
      expect(sprPreviewTex('3/'), isNull);
      expect(sprPreviewTex('1 1/2'), isNull);
      expect(sprPreviewTex('3/0'), isNull);
    });
  });
}
