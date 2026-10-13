// test/core/theme/booklet_colors_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/theme/booklet_colors.dart';

void main() {
  test(
    'F-4: brand primary is the ballpoint blue, not the seed placeholder',
    () {
      expect(BookletSchemes.light.primary, const Color(0xFF1F4FD6));
      expect(BookletSchemes.dark.primary, const Color(0xFF86A5FF));
    },
  );

  test('F-4: red pen and ink match Foundations', () {
    expect(BookletSchemes.light.error, const Color(0xFFD2343A));
    expect(BookletSchemes.light.onSurface, const Color(0xFF1A1D24));
    expect(BookletSchemes.dark.surface, const Color(0xFF11141A));
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

  test('F-4: copyWith replaces only the given field', () {
    const red = Color(0xFFFF0000);
    final c = BookletColors.light.copyWith(info: red);
    expect(c.info, red);
    expect(c.warning, BookletColors.light.warning);
  });

  test('F-4: scheme scrim is translucent (ink 48% light, black 60% dark)', () {
    expect(BookletSchemes.light.scrim, const Color(0x7A1A1D24));
    expect(BookletSchemes.dark.scrim, const Color(0x99000000));
  });

  test('F-4: nav indicator and tonal roles use the selected tint', () {
    expect(
      BookletSchemes.light.secondaryContainer,
      BookletSchemes.light.primaryContainer,
    );
    expect(
      BookletSchemes.dark.secondaryContainer,
      BookletSchemes.dark.primaryContainer,
    );
    expect(
      BookletSchemes.light.tertiaryContainer,
      BookletSchemes.light.primaryContainer,
    );
    expect(
      BookletSchemes.light.onSecondaryContainer,
      BookletSchemes.light.onSurface,
    );
  });

  test('F-4: booklet colors have value equality', () {
    expect(BookletColors.light.copyWith(), BookletColors.light);
    expect(
      BookletColors.light.copyWith().hashCode,
      BookletColors.light.hashCode,
    );
    expect(BookletColors.light, isNot(BookletColors.dark));
  });

  test('F-4: lerp at 0 and 1 returns the endpoints for every field', () {
    expect(
      BookletColors.light.lerp(BookletColors.dark, 0),
      BookletColors.light,
    );
    expect(BookletColors.light.lerp(BookletColors.dark, 1), BookletColors.dark);
  });
}
