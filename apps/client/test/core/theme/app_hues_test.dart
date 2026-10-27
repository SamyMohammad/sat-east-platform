import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_hues.dart';

void main() {
  test('forIndex_cycles', () {
    expect(
      [for (var i = 0; i < 7; i++) SubjectHue.forIndex(i)],
      [
        SubjectHue.blue,
        SubjectHue.teal,
        SubjectHue.violet,
        SubjectHue.amber,
        SubjectHue.rose,
        SubjectHue.blue,
        SubjectHue.teal,
      ],
    );
    expect(SubjectHue.forIndex(-1), SubjectHue.rose);
  });
  for (final brightness in Brightness.values) {
    test('hue_on_wash_meets_3_to_1_${brightness.name}', () {
      for (final hue in SubjectHue.values) {
        expect(
          _ratio(hue.color(brightness), hue.wash(brightness)),
          greaterThanOrEqualTo(3),
          reason: hue.name,
        );
      }
    });
    test('hue_on_background_meets_3_to_1_${brightness.name}', () {
      final colors = brightness == Brightness.light
          ? AppColors.light
          : AppColors.dark;
      for (final hue in SubjectHue.values) {
        expect(
          _ratio(hue.color(brightness), colors.background),
          greaterThanOrEqualTo(3),
          reason: hue.name,
        );
      }
    });
  }
}

double _ratio(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
}
