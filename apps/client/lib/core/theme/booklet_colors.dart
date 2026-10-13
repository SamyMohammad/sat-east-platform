import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

/// Material roles, hex from Foundations.dc.html (light + dark columns).
abstract final class BookletSchemes {
  static const ColorScheme light = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF1F4FD6),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFE9EEFB),
    onPrimaryContainer: Color(0xFF1A1D24),
    secondary: Color(0xFF4B5262),
    onSecondary: Color(0xFFFFFFFF),
    error: Color(0xFFD2343A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFBEBEC),
    onErrorContainer: Color(0xFF1A1D24),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF1A1D24),
    onSurfaceVariant: Color(0xFF4B5262),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFFF6F7F9),
    surfaceContainerHigh: Color(0xFFF6F7F9),
    surfaceContainerHighest: Color(0xFFEEF2F8),
    outline: Color(0xFF1A1D24),
    outlineVariant: Color(0xFFD8DDE6),
    inverseSurface: Color(0xFF1A1D24),
    onInverseSurface: Color(0xFFFFFFFF),
    inversePrimary: Color(0xFF86A5FF),
    shadow: Color(0xFF1A1D24),
    scrim: Color(0x7A1A1D24), // ink @ 48%
    surfaceTint: Color(0x00000000),
    // Booklet has one accent; tonal/indicator roles reuse the selected tint (App Shell active pill).
    secondaryContainer: Color(0xFFE9EEFB),
    onSecondaryContainer: Color(0xFF1A1D24),
    tertiary: Color(0xFF4B5262),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFE9EEFB),
    onTertiaryContainer: Color(0xFF1A1D24),
  );

  static const ColorScheme dark = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF86A5FF),
    onPrimary: Color(0xFF0B1026),
    primaryContainer: Color(0xFF1C2850),
    onPrimaryContainer: Color(0xFFE7E9EE),
    secondary: Color(0xFFA8AFBC),
    onSecondary: Color(0xFF11141A),
    error: Color(0xFFFF7A7E),
    onError: Color(0xFF11141A),
    errorContainer: Color(0xFF3A1D21),
    onErrorContainer: Color(0xFFE7E9EE),
    surface: Color(0xFF11141A),
    onSurface: Color(0xFFE7E9EE),
    onSurfaceVariant: Color(0xFFA8AFBC),
    surfaceContainerLowest: Color(0xFF11141A),
    surfaceContainerLow: Color(0xFF181C24),
    surfaceContainer: Color(0xFF1D222C),
    surfaceContainerHigh: Color(0xFF1D222C),
    surfaceContainerHighest: Color(0xFF1E2533),
    outline: Color(0xFFE7E9EE),
    outlineVariant: Color(0xFF2B313D),
    inverseSurface: Color(0xFFE7E9EE),
    onInverseSurface: Color(0xFF11141A),
    inversePrimary: Color(0xFF1F4FD6),
    shadow: Color(0xFF000000),
    scrim: Color(0x99000000), // black @ 60%
    surfaceTint: Color(0x00000000),
    // Booklet has one accent; tonal/indicator roles reuse the selected tint (App Shell active pill).
    secondaryContainer: Color(0xFF1C2850),
    onSecondaryContainer: Color(0xFFE7E9EE),
    tertiary: Color(0xFFA8AFBC),
    onTertiary: Color(0xFF11141A),
    tertiaryContainer: Color(0xFF1C2850),
    onTertiaryContainer: Color(0xFFE7E9EE),
  );
}

/// Booklet roles Material has no slot for (Foundations.dc.html,
/// QuestionView.dc.html exam bar). Read with `context.booklet`.
@immutable
class BookletColors extends ThemeExtension<BookletColors> {
  const BookletColors({
    required this.frameTint,
    required this.inkDisabled,
    required this.primaryHover,
    required this.greenTick,
    required this.greenTickContainer,
    required this.highlighter,
    required this.onHighlighter,
    required this.warning,
    required this.warningContainer,
    required this.info,
    required this.infoContainer,
    required this.examBar,
    required this.onExamBar,
    required this.onExamBarVariant,
    required this.examBarRule,
    required this.examBarPrimary,
    required this.examBarWarning,
    required this.scrim,
    required this.overlayShadow,
  });

  static const light = BookletColors(
    frameTint: Color(0xFFEEF2F8),
    inkDisabled: Color(0xFF9AA1AD),
    primaryHover: Color(0xFF1B45BC),
    greenTick: Color(0xFF1E7F4F),
    greenTickContainer: Color(0xFFE4F2EA),
    highlighter: Color(0xFFF6D743),
    onHighlighter: Color(0xFF1A1D24),
    warning: Color(0xFFB45309),
    warningContainer: Color(0xFFFCEFE1),
    info: Color(0xFF0E6A86),
    infoContainer: Color(0xFFE3F1F5),
    examBar: Color(0xFF1A1D24),
    onExamBar: Color(0xFFE7E9EE),
    onExamBarVariant: Color(0xFFA8AFBC),
    examBarRule: Color(0xFF3A404D),
    examBarPrimary: Color(0xFF86A5FF),
    examBarWarning: Color(0xFFF5A04D),
    scrim: Color(0x7A1A1D24), // ink @ 48%
    overlayShadow: Color(0x1A1A1D24), // ink @ 10%
  );

  /// Exam bar is already ink-dark; the design has no separate dark bar.
  static const dark = BookletColors(
    frameTint: Color(0xFF1E2533),
    inkDisabled: Color(0xFF5E6573),
    primaryHover: Color(0xFF98B2FD),
    greenTick: Color(0xFF5BC48C),
    greenTickContainer: Color(0xFF16301F),
    highlighter: Color(0xFFE9C935),
    onHighlighter: Color(0xFF1A1D24),
    warning: Color(0xFFF5A04D),
    warningContainer: Color(0xFF3A2614),
    info: Color(0xFF5BC0DC),
    infoContainer: Color(0xFF13303A),
    examBar: Color(0xFF1A1D24),
    onExamBar: Color(0xFFE7E9EE),
    onExamBarVariant: Color(0xFFA8AFBC),
    examBarRule: Color(0xFF3A404D),
    examBarPrimary: Color(0xFF86A5FF),
    examBarWarning: Color(0xFFF5A04D),
    scrim: Color(0x99000000), // black @ 60%
    overlayShadow: Color(0x00000000), // no shadow in dark
  );

  final Color frameTint;
  final Color inkDisabled;
  final Color primaryHover;
  final Color greenTick;
  final Color greenTickContainer;
  final Color highlighter;
  final Color onHighlighter;
  final Color warning;
  final Color warningContainer;
  final Color info;
  final Color infoContainer;
  final Color examBar;
  final Color onExamBar;
  final Color onExamBarVariant;
  final Color examBarRule;
  final Color examBarPrimary;
  final Color examBarWarning;
  final Color scrim;
  final Color overlayShadow;

  List<Color> get _fields => [
    frameTint,
    inkDisabled,
    primaryHover,
    greenTick,
    greenTickContainer,
    highlighter,
    onHighlighter,
    warning,
    warningContainer,
    info,
    infoContainer,
    examBar,
    onExamBar,
    onExamBarVariant,
    examBarRule,
    examBarPrimary,
    examBarWarning,
    scrim,
    overlayShadow,
  ];

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    return other is BookletColors && listEquals(_fields, other._fields);
  }

  @override
  int get hashCode => Object.hashAll(_fields);

  @override
  BookletColors copyWith({
    Color? frameTint,
    Color? inkDisabled,
    Color? primaryHover,
    Color? greenTick,
    Color? greenTickContainer,
    Color? highlighter,
    Color? onHighlighter,
    Color? warning,
    Color? warningContainer,
    Color? info,
    Color? infoContainer,
    Color? examBar,
    Color? onExamBar,
    Color? onExamBarVariant,
    Color? examBarRule,
    Color? examBarPrimary,
    Color? examBarWarning,
    Color? scrim,
    Color? overlayShadow,
  }) {
    return BookletColors(
      frameTint: frameTint ?? this.frameTint,
      inkDisabled: inkDisabled ?? this.inkDisabled,
      primaryHover: primaryHover ?? this.primaryHover,
      greenTick: greenTick ?? this.greenTick,
      greenTickContainer: greenTickContainer ?? this.greenTickContainer,
      highlighter: highlighter ?? this.highlighter,
      onHighlighter: onHighlighter ?? this.onHighlighter,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
      examBar: examBar ?? this.examBar,
      onExamBar: onExamBar ?? this.onExamBar,
      onExamBarVariant: onExamBarVariant ?? this.onExamBarVariant,
      examBarRule: examBarRule ?? this.examBarRule,
      examBarPrimary: examBarPrimary ?? this.examBarPrimary,
      examBarWarning: examBarWarning ?? this.examBarWarning,
      scrim: scrim ?? this.scrim,
      overlayShadow: overlayShadow ?? this.overlayShadow,
    );
  }

  @override
  BookletColors lerp(covariant ThemeExtension<BookletColors>? other, double t) {
    if (other is! BookletColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return BookletColors(
      frameTint: c(frameTint, other.frameTint),
      inkDisabled: c(inkDisabled, other.inkDisabled),
      primaryHover: c(primaryHover, other.primaryHover),
      greenTick: c(greenTick, other.greenTick),
      greenTickContainer: c(greenTickContainer, other.greenTickContainer),
      highlighter: c(highlighter, other.highlighter),
      onHighlighter: c(onHighlighter, other.onHighlighter),
      warning: c(warning, other.warning),
      warningContainer: c(warningContainer, other.warningContainer),
      info: c(info, other.info),
      infoContainer: c(infoContainer, other.infoContainer),
      examBar: c(examBar, other.examBar),
      onExamBar: c(onExamBar, other.onExamBar),
      onExamBarVariant: c(onExamBarVariant, other.onExamBarVariant),
      examBarRule: c(examBarRule, other.examBarRule),
      examBarPrimary: c(examBarPrimary, other.examBarPrimary),
      examBarWarning: c(examBarWarning, other.examBarWarning),
      scrim: c(scrim, other.scrim),
      overlayShadow: c(overlayShadow, other.overlayShadow),
    );
  }
}

extension BookletThemeContext on BuildContext {
  /// Booklet roles of the current theme. Set by `AppTheme`.
  BookletColors get booklet {
    final ext = Theme.of(this).extension<BookletColors>();
    if (ext == null) {
      throw FlutterError(
        'BookletColors missing: wrap the tree in AppTheme.light()/dark()',
      );
    }
    return ext;
  }
}
