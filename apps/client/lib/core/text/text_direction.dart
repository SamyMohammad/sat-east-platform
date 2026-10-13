import 'package:flutter/widgets.dart';

// Hebrew/Arabic blocks + Arabic presentation forms.
final _rtl = RegExp('[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]');
final _ltr = RegExp('[A-Za-z\u00C0-\u024F]');

/// Direction of a content paragraph from its first strong letter (rule 8).
TextDirection detectTextDirection(
  String text, {
  TextDirection fallback = TextDirection.ltr,
}) {
  for (final rune in text.runes) {
    final ch = String.fromCharCode(rune);
    if (_rtl.hasMatch(ch)) return TextDirection.rtl;
    if (_ltr.hasMatch(ch)) return TextDirection.ltr;
  }
  return fallback;
}
