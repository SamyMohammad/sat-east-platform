import 'package:flutter/material.dart';

enum SubjectHue {
  blue(0xFF2F6FAD, 0xFFE6F4FC, 0xFF7FB3E0, 0xFF15324A),
  teal(0xFF0E9F8E, 0xFFF4FCFA, 0xFF4DD4BF, 0xFF123832),
  violet(0xFF7C5CE0, 0xFFF4F0FE, 0xFFB49AFF, 0xFF302347),
  // The spec amber is 2.77:1 on white; this shade clears icon contrast.
  amber(0xFFCE8200, 0xFFFFFDF8, 0xFFF2BE62, 0xFF382A14),
  rose(0xFFE0567A, 0xFFFFF5F8, 0xFFFF90AD, 0xFF3B202C);

  const SubjectHue(this._light, this._lightWash, this._dark, this._darkWash);

  final int _light;
  final int _lightWash;
  final int _dark;
  final int _darkWash;

  Color color(Brightness brightness) =>
      Color(brightness == Brightness.light ? _light : _dark);

  Color wash(Brightness brightness) =>
      Color(brightness == Brightness.light ? _lightWash : _darkWash);

  static SubjectHue forIndex(int i) => values[i % values.length];
}
