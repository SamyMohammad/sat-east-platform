// test/core/theme/booklet_colors_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/theme/booklet_colors.dart';

void main() {
  test(
    'F-4: brand primary is the ballpoint blue, not the seed placeholder',
    () {
      expect(BookletSchemes.light.primary, const Color(0xFF2F5BEA));
      expect(BookletSchemes.dark.primary, const Color(0xFF7C9BFF));
    },
  );

  test('F-4: red pen and ink match Foundations', () {
    expect(BookletSchemes.light.error, const Color(0xFFC9392F));
    expect(BookletSchemes.light.onSurface, const Color(0xFF14171F));
    expect(BookletSchemes.dark.surface, const Color(0xFF0F1218));
  });

  test('F-4: every non-exam-bar booklet role has its own dark value', () {
    const l = BookletColors.light;
    const d = BookletColors.dark;
    final pairs = <String, (Color, Color)>{
      'frameTint': (l.frameTint, d.frameTint),
      'inkDisabled': (l.inkDisabled, d.inkDisabled),
      'primaryHover': (l.primaryHover, d.primaryHover),
      'greenTick': (l.greenTick, d.greenTick),
      'greenTickContainer': (l.greenTickContainer, d.greenTickContainer),
      'highlighter': (l.highlighter, d.highlighter),
      'warning': (l.warning, d.warning),
      'warningContainer': (l.warningContainer, d.warningContainer),
      'info': (l.info, d.info),
      'infoContainer': (l.infoContainer, d.infoContainer),
      'scrim': (l.scrim, d.scrim),
      'overlayShadow': (l.overlayShadow, d.overlayShadow),
    };
    for (final MapEntry(key: name, value: p) in pairs.entries) {
      expect(p.$1, isNot(p.$2), reason: name);
    }
  });

  test('F-4: lerp at 0 and 1 returns the endpoints', () {
    const l = BookletColors.light;
    const d = BookletColors.dark;
    expect(l.lerp(d, 0).greenTick, l.greenTick);
    expect(l.lerp(d, 1).greenTick, d.greenTick);
    expect(l.lerp(d, 1).examBarWarning, d.examBarWarning);
  });

  test('F-4: copyWith replaces only the given field', () {
    const red = Color(0xFFFF0000);
    final c = BookletColors.light.copyWith(info: red);
    expect(c.info, red);
    expect(c.warning, BookletColors.light.warning);
  });
}
