# F-4 row 6 — Design system + QuestionView Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Flutter design system ("The Teacher's Booklet") + the one shared `QuestionView`, matching `docs/design/claude-design-export/`, so practice / homework / quiz / mock can be built on it.

**Architecture:** Tokens become a hand-built `ColorScheme` + `BookletColors` `ThemeExtension` + `TextTheme` + const token classes in `lib/core/theme/`. Math is one widget, `MathText` (`lib/core/math_render/`), over a pure-Dart markup parser and `flutter_math_fork`; it is the only place that knows the math engine. Shared widgets live in `lib/shared/widgets/`, take data + callbacks only (no Cubit, no Supabase).

**Tech Stack:** Flutter 3.44.1 / Dart ^3.12.1, `flutter_math_fork` ^0.7.4 (pending spike), `equatable` (already a dependency), bundled Noto Sans + Noto Sans Arabic, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-13-f4-design-system-questionview-design.md` (approved 2026-10-13). Design source: `docs/design/claude-design-export/` (`Foundations.dc.html`, `Components.dc.html`, `App Shell.dc.html`, `QuestionView*.dc.html`, `booklet-math.js`).

## Context
Row 6 of `docs/15` §1 (F-4). Claude Design is finished and verified (`docs/design/claude-design-coverage.md`). Nothing exists yet on the client: `lib/core/theme/app_theme.dart` is a `fromSeed(0xFF1E5EFF)` placeholder, `lib/shared/widgets/` is empty, no math or font packages. Four features depend on this (rule 6).

## How this plan is split (and why)
The spec delivers six PRs. This document is **fully detailed for the first three steps** (math spike gate, theme + tokens, `MathText`) because they are fixed by the spec today. Steps 4–7 (components, shell, `QuestionView`, gallery) are listed with their locked file names, public APIs and acceptance criteria; each gets its own detailed plan (writing-plans) when reached, because the spike can swap the math engine and the components build on the shipped theme API. Deviation from the spec's step order: fonts ship with the theme PR (not the spike), and `MathText` is its own PR.

## Global Constraints
- Branch per PR from `main`, after PR #12 (`docs/F-4-design-brief`, holds the spec) is merged. Spike branch `spike/F-4-math-web` is throwaway, never merged.
- Layers / rules: CLAUDE.md A.1–A.7, B.1–B.9. No `freezed`/`json_serializable`/`build_runner`. `const` wherever possible.
- No hard-coded colors, sizes or durations in widgets: read from `Theme.of(context)`, `context.booklet`, or the token classes.
- Rule 1: no answer-key field anywhere in client question models.
- Rule 8: content text direction is detected per paragraph (`detectTextDirection`); math is always an LTR isolate.
- `very_good_analysis`; `dart format .`, `flutter analyze --fatal-infos`, `flutter test` clean before each commit (run from `apps/client/`).
- Test names start with `F-4:`. `*_test.dart` files are written by the `test-writer` agent (CLAUDE.md A.9) with the content given here.
- Dependencies: only `flutter_math_fork` is added in this plan. No `google_fonts` (9.0.0 needs Dart ^3.13; also offline/CSP).
- Icons: built-in Material `Icons.*_rounded` (filled vs `*_outlined` for active/inactive). No Material Symbols font (YAGNI; removes the variable-font risk in the spec).
- Mono font: not bundled in this plan (only used for kbd hints in the mock laptop footer); decided in the `QuestionView` plan.
- Fonts are downloaded files: the executor asks the user before downloading (filename, source, size).
- Commits end with a blank line + `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Git via `git-expert` agent.

## Review Focus
1. Malformed markup (`\(x` unclosed, `\frac{` bad TeX, `\(\)` empty, stray `**`) → rendered as literal text, never an exception. Pinned in Task 5.
2. Arabic paragraph with inline math and trailing punctuation → paragraph RTL, math LTR, punctuation stays attached to the formula. Pinned in Task 5.
3. 360 px width with text scale 2.0 and a long display formula → no overflow; single block scrolls horizontally, `||` blocks wrap. Pinned in Task 5.
4. Reduced motion (`MediaQuery.disableAnimations`) → slow transitions become instant, base becomes fast. Pinned in Task 2.
5. Dark theme missing a booklet role (field forgotten in `copyWith`/`lerp`/`dark`) → every field differs light vs dark except the exam-bar set; theme switch animates without null. Pinned in Task 3.

---

## Task 0: Save the plan and branch

- [ ] **Step 1:** Copy this plan to `docs/superpowers/plans/2026-10-13-f4-design-system.md`.
- [ ] **Step 2:** Confirm PR #12 is merged (`gh pr view 12 --json state`). If not, stop and tell the user (the spec lives there).
- [ ] **Step 3:** `git-expert`: branch `spike/F-4-math-web` from `main` for Task 1.

---

## Task 1: Math spike on web (decision gate, throwaway)

Answers one question: does `flutter_math_fork` render question stems correctly and fast enough on web (CanvasKit and `--wasm`) at 360 px, and on Android? Output is a written verdict, not code to keep.

**Files (throwaway branch only):**
- Modify: `apps/client/pubspec.yaml` (add `flutter_math_fork`)
- Create: `apps/client/lib/spike_math_main.dart`

- [ ] **Step 1: Add the package**

Run (from `apps/client/`): `flutter pub add flutter_math_fork:^0.7.4`
Expected: resolves with Flutter 3.44.1. If resolution fails → verdict FAIL (reason: incompatible), skip to Step 5.

- [ ] **Step 2: Write the spike page**

```dart
// lib/spike_math_main.dart — THROWAWAY (spike/F-4-math-web), never merged.
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

const _stems = <String>[
  r'If 2x + 3 = 11, what is the value of 4x − 1? Inline: ',
  r'The function f is defined by f(x) = ',
  r'لدينا المعادلة ',
];
const _inline = <String>[
  r'2x+3=11',
  r'\dfrac{x^2-9}{x-3}',
  r'\sqrt{b^2-4ac}',
];
const _block = r'\frac{3}{x-2}+\frac{5}{x+2}=\frac{4x+1}{x^2-4}';

void main() => runApp(const _Spike());

class _Spike extends StatelessWidget {
  const _Spike();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 60,
          itemBuilder: (context, i) {
            final stem = _stems[i % _stems.length];
            final tex = _inline[i % _inline.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      text: stem * 3,
                      children: [
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: Directionality(
                            textDirection: TextDirection.ltr,
                            child: Math.tex(tex, mathStyle: MathStyle.text),
                          ),
                        ),
                        const TextSpan(text: '. Then continue the sentence.'),
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Math.tex(_block, mathStyle: MathStyle.display),
                  ),
                  Math.tex(r'\frac{', onErrorFallback: (e) => Text('ERR: ${e.message}')),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Run and measure**

Run each and check the list below at a 360 px wide Chrome window (DevTools device toolbar) and at 1280:
- `flutter run -d chrome --profile -t lib/spike_math_main.dart`
- `flutter build web --release --wasm -t lib/spike_math_main.dart` then serve `build/web` (`npx -y serve build/web`) and open it
- `flutter run --profile -t lib/spike_math_main.dart` on an Android device/emulator (`--flavor dev` not needed for this entrypoint; if the Gradle flavor setup demands it, use `--flavor dev`)

Checklist (record PASS/FAIL + numbers):
1. KaTeX glyphs render (fractions, roots, Greek), no tofu boxes.
2. Inline math sits on the text baseline; trailing text continues on the same line.
3. Arabic paragraph shows RTL with the formula LTR inside it.
4. Display formula scrolls horizontally at 360, no overflow stripe.
5. Invalid TeX shows the `ERR:` fallback, no red error screen.
6. Text scaling: set browser zoom / Android font size to 200%. Does `Math.tex` grow by itself? Record yes/no (Task 5 depends on this).
7. Performance (DevTools Performance tab, profile mode): scroll the 60-item list; frame build time p90 < 16 ms after first paint; first paint of the page < 1 s on desktop Chrome.
8. `build/web` size delta vs `main` build (`du -sh build/web` both) — record only.

- [ ] **Step 4: Decide**
- All of 1–5 and 7 PASS → verdict PASS, keep `flutter_math_fork`.
- Any FAIL → verdict FAIL. Stop the plan, report to the user, re-plan Task 5 on `gpt_markdown` (spec "Risks").

- [ ] **Step 5: Record the verdict**

Append to the spec file (done on the Task 2 branch, not the spike branch) a section:
```markdown
## Spike result (2026-10-xx)
Verdict: PASS|FAIL. Flutter 3.44.1, flutter_math_fork 0.7.4.
1–8: <PASS/FAIL + numbers per checklist item>
Math.tex follows text scaling by itself: yes|no.
```
Delete the spike branch locally and remotely (`git-expert`) after recording; never merge it.

---

## Task 2: Fonts + design tokens

Starts PR "feat(F-4): theme and tokens" on branch `feat/F-4-theme` from `main`.

**Files:**
- Create: `apps/client/assets/fonts/NotoSans-Regular.ttf`, `NotoSans-Medium.ttf`, `NotoSans-SemiBold.ttf`, `NotoSans-Bold.ttf`, `NotoSansArabic-Regular.ttf`, `NotoSansArabic-SemiBold.ttf`, `OFL.txt`
- Modify: `apps/client/pubspec.yaml` (`flutter: fonts:`)
- Create: `apps/client/lib/core/theme/booklet_tokens.dart`
- Test: `apps/client/test/core/theme/booklet_tokens_test.dart`

**Interfaces:**
- Produces: `BookletSpace.{s1,s2,s3,s4,s6,s8,s12,s16}` (double), `BookletRadius.{none,xs,sm,md}` (double), `BookletSize.{touchTarget,readingColumn,questionColumn,blockMathMinHeight}` (double), `BookletLayout` enum `{compact, medium, expanded}` + `BookletLayout.forWidth(double)`, `BookletMotion.{fast,base,slow}` (Duration), `BookletMotion.{standard,enter,exit}` (Curve), `BookletMotion.resolve(BuildContext, Duration) → Duration`.

- [ ] **Step 1: Get the fonts (ask the user first)**

Ask the user to approve downloading the "Noto Sans" and "Noto Sans Arabic" family zips from fonts.google.com (static TTFs, SIL OFL 1.1, a few MB each). Copy only the six static files listed above from each zip's `static/` folder into `apps/client/assets/fonts/`, plus `OFL.txt`. Extract into an empty scratch folder, not the repo.

- [ ] **Step 2: Declare fonts in `pubspec.yaml`** (replace the commented `fonts:` example under `flutter:`)

```yaml
flutter:
  uses-material-design: true
  fonts:
    - family: NotoSans
      fonts:
        - asset: assets/fonts/NotoSans-Regular.ttf
        - asset: assets/fonts/NotoSans-Medium.ttf
          weight: 500
        - asset: assets/fonts/NotoSans-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/NotoSans-Bold.ttf
          weight: 700
    - family: NotoSansArabic
      fonts:
        - asset: assets/fonts/NotoSansArabic-Regular.ttf
        - asset: assets/fonts/NotoSansArabic-SemiBold.ttf
          weight: 600
```
Run: `flutter pub get`. Expected: no asset errors.

- [ ] **Step 3: Write the failing test** (via `test-writer`)

```dart
// test/core/theme/booklet_tokens_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';

void main() {
  test('F-4: layout breakpoints follow the app shell (600 / 1024)', () {
    expect(BookletLayout.forWidth(360), BookletLayout.compact);
    expect(BookletLayout.forWidth(600), BookletLayout.compact);
    expect(BookletLayout.forWidth(768), BookletLayout.medium);
    expect(BookletLayout.forWidth(1023), BookletLayout.medium);
    expect(BookletLayout.forWidth(1024), BookletLayout.expanded);
    expect(BookletLayout.forWidth(1280), BookletLayout.expanded);
  });

  test('F-4: touch target is 48 and spacing is on the 4-pt grid', () {
    expect(BookletSize.touchTarget, 48);
    for (final v in [
      BookletSpace.s1, BookletSpace.s2, BookletSpace.s3, BookletSpace.s4,
      BookletSpace.s6, BookletSpace.s8, BookletSpace.s12, BookletSpace.s16,
    ]) {
      expect(v % 4, 0);
    }
  });

  Future<Duration> resolveWith(
    WidgetTester tester, {
    required bool reduced,
    required Duration duration,
  }) async {
    late Duration result;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Builder(
          builder: (context) {
            result = BookletMotion.resolve(context, duration);
            return const SizedBox();
          },
        ),
      ),
    );
    return result;
  }

  testWidgets('F-4: motion is unchanged without reduced motion', (t) async {
    expect(
      await resolveWith(t, reduced: false, duration: BookletMotion.slow),
      BookletMotion.slow,
    );
  });

  testWidgets('F-4: reduced motion makes slow instant', (t) async {
    expect(
      await resolveWith(t, reduced: true, duration: BookletMotion.slow),
      Duration.zero,
    );
  });

  testWidgets('F-4: reduced motion turns base into fast', (t) async {
    expect(
      await resolveWith(t, reduced: true, duration: BookletMotion.base),
      BookletMotion.fast,
    );
  });
}
```

- [ ] **Step 4: Run to verify it fails**

Run: `flutter test test/core/theme/booklet_tokens_test.dart`
Expected: FAIL — `booklet_tokens.dart` not found.

- [ ] **Step 5: Implement**

```dart
// lib/core/theme/booklet_tokens.dart
import 'package:flutter/widgets.dart';

/// Spacing scale, 4-pt (Foundations.dc.html "space.*").
abstract final class BookletSpace {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s6 = 24;
  static const double s8 = 32;
  static const double s12 = 48;
  static const double s16 = 64;
}

/// Corner radii (Foundations.dc.html "radius.*").
abstract final class BookletRadius {
  static const double none = 0;
  static const double xs = 2;
  static const double sm = 4;
  static const double md = 8;
}

/// Fixed sizes shared by many widgets.
abstract final class BookletSize {
  static const double touchTarget = 48;
  static const double readingColumn = 640;
  static const double questionColumn = 720;
  static const double blockMathMinHeight = 64;
}

/// App shell layouts: bottom nav, rail, sidebar (App Shell.dc.html).
enum BookletLayout {
  compact,
  medium,
  expanded;

  static BookletLayout forWidth(double width) {
    if (width <= 600) return compact;
    if (width < 1024) return medium;
    return expanded;
  }
}

/// Motion tokens (Foundations.dc.html "motion.*"). No bounce or spring.
abstract final class BookletMotion {
  static const Duration fast = Duration(milliseconds: 100);
  static const Duration base = Duration(milliseconds: 180);
  static const Duration slow = Duration(milliseconds: 280);

  static const Curve standard = Cubic(0.2, 0, 0, 1);
  static const Curve enter = Cubic(0.05, 0.7, 0.1, 1);
  static const Curve exit = Cubic(0.3, 0, 0.8, 0.15);

  /// Applies reduced motion: slow → instant, base → fast fade.
  static Duration resolve(BuildContext context, Duration duration) {
    if (!MediaQuery.disableAnimationsOf(context)) return duration;
    if (duration >= slow) return Duration.zero;
    return duration > fast ? fast : duration;
  }
}
```

- [ ] **Step 6: Run to verify it passes**

Run: `flutter test test/core/theme/booklet_tokens_test.dart` → PASS. Then `dart format .` and `flutter analyze --fatal-infos` → clean.

- [ ] **Step 7: Commit** (`git-expert`): `feat(F-4): bundle Noto fonts and add design tokens`

---

## Task 3: Colors (`ColorScheme` + `BookletColors`)

**Files:**
- Create: `apps/client/lib/core/theme/booklet_colors.dart`
- Test: `apps/client/test/core/theme/booklet_colors_test.dart`

**Interfaces:**
- Produces: `BookletColors` (`ThemeExtension`) with fields `frameTint, inkDisabled, primaryHover, greenTick, greenTickContainer, highlighter, onHighlighter, warning, warningContainer, info, infoContainer, examBar, onExamBar, onExamBarVariant, examBarRule, examBarPrimary, examBarWarning, scrim, overlayShadow` (all `Color`); `BookletColors.light`, `BookletColors.dark`; `BookletSchemes.light`, `BookletSchemes.dark` (`ColorScheme`); `extension BookletThemeContext on BuildContext { BookletColors get booklet; }`.

- [ ] **Step 1: Write the failing test** (via `test-writer`)

```dart
// test/core/theme/booklet_colors_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/theme/booklet_colors.dart';

void main() {
  test('F-4: brand primary is the ballpoint blue, not the seed placeholder', () {
    expect(BookletSchemes.light.primary, const Color(0xFF1F4FD6));
    expect(BookletSchemes.dark.primary, const Color(0xFF86A5FF));
  });

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
    pairs.forEach((name, p) => expect(p.$1, isNot(p.$2), reason: name));
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
```

- [ ] **Step 2: Run to verify it fails** — `flutter test test/core/theme/booklet_colors_test.dart` → FAIL (file missing).

- [ ] **Step 3: Implement**

```dart
// lib/core/theme/booklet_colors.dart
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
    scrim: Color(0xFF1A1D24),
    surfaceTint: Color(0x00000000),
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
    scrim: Color(0xFF000000),
    surfaceTint: Color(0x00000000),
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
  BookletColors get booklet => Theme.of(this).extension<BookletColors>()!;
}
```

- [ ] **Step 4: Run to verify it passes** — test PASS; `dart format .`; `flutter analyze --fatal-infos` clean.
- [ ] **Step 5: Commit**: `feat(F-4): booklet color scheme and theme extension`

---

## Task 4: Typography + `AppTheme`

**Files:**
- Create: `apps/client/lib/core/theme/booklet_type.dart`
- Modify: `apps/client/lib/core/theme/app_theme.dart` (full rewrite; public API `AppTheme.light()` / `AppTheme.dark()` unchanged, so `lib/app.dart` needs no edit)
- Test: `apps/client/test/core/theme/app_theme_test.dart`

**Interfaces:**
- Consumes: Task 2 tokens, Task 3 `BookletSchemes`, `BookletColors`.
- Produces: `BookletFonts.{sans,arabic}` (String), `BookletType.textTheme()`, `BookletType.timer`, `BookletType.arabic` (TextStyle), `BookletType.mathScale` (double = 1.21), `AppTheme.light()`, `AppTheme.dark()`.

- [ ] **Step 1: Write the failing test** (via `test-writer`)

```dart
// test/core/theme/app_theme_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/core/theme/booklet_colors.dart';
import 'package:sat_east_client/core/theme/booklet_type.dart';

void main() {
  for (final (name, theme, scheme, booklet) in [
    ('light', AppTheme.light(), BookletSchemes.light, BookletColors.light),
    ('dark', AppTheme.dark(), BookletSchemes.dark, BookletColors.dark),
  ]) {
    test('F-4: $name theme uses the booklet scheme and extension', () {
      expect(theme.colorScheme, scheme);
      expect(theme.extension<BookletColors>(), booklet);
    });
  }

  test('F-4: question stem style is 18/28 regular Noto Sans', () {
    final stem = AppTheme.light().textTheme.bodyLarge!;
    expect(stem.fontSize, 18);
    expect(stem.height, closeTo(28 / 18, 1e-9));
    expect(stem.fontWeight, FontWeight.w400);
    expect(stem.fontFamily, BookletFonts.sans);
  });

  test('F-4: buttons meet the 48 px touch target', () {
    final style = AppTheme.light().filledButtonTheme.style!;
    expect(style.minimumSize!.resolve({})!.height, 48);
  });

  test('F-4: no ripple (booklet has no splash)', () {
    expect(AppTheme.light().splashFactory, NoSplash.splashFactory);
  });

  test('F-4: dark overlays have no elevation shadow', () {
    expect(AppTheme.dark().dialogTheme.elevation, 0);
    expect(AppTheme.light().dialogTheme.elevation, greaterThan(0));
  });

  test('F-4: timer uses tabular figures', () {
    expect(
      BookletType.timer.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });

  testWidgets('F-4: context.booklet resolves under AppTheme', (tester) async {
    late BookletColors resolved;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            resolved = context.booklet;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(resolved, BookletColors.light);
  });
}
```

- [ ] **Step 2: Run to verify it fails** — FAIL (`booklet_type.dart` missing; `colorScheme` mismatch).

- [ ] **Step 3: Implement typography**

```dart
// lib/core/theme/booklet_type.dart
import 'package:flutter/material.dart';

/// Bundled families (pubspec `fonts:`).
abstract final class BookletFonts {
  static const String sans = 'NotoSans';
  static const String arabic = 'NotoSansArabic';
}

/// Type scale from Foundations.dc.html "type.*".
/// `labelSmall` is the caption style; callers upper-case its text.
abstract final class BookletType {
  /// Math renders at 1.21 em of the surrounding text (Foundations).
  static const double mathScale = 1.21;

  static TextTheme textTheme() => const TextTheme(
    displaySmall: TextStyle(
      fontSize: 40,
      height: 48 / 40,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.8,
    ),
    headlineSmall: TextStyle(
      fontSize: 28,
      height: 36 / 28,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.28,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      height: 28 / 20,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
    bodyLarge: TextStyle(
      fontSize: 18,
      height: 28 / 18,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
    ),
    bodyMedium: TextStyle(
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.14,
    ),
    labelSmall: TextStyle(
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.72,
    ),
  );

  /// Exam clock: 20/24, tabular figures so digits do not jump.
  static const TextStyle timer = TextStyle(
    fontFamily: BookletFonts.sans,
    fontSize: 20,
    height: 24 / 20,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Arabic body: 16/28 (decision in spec), Latin falls back to Noto Sans.
  static const TextStyle arabic = TextStyle(
    fontFamily: BookletFonts.arabic,
    fontFamilyFallback: [BookletFonts.sans],
    fontSize: 16,
    height: 28 / 16,
    fontWeight: FontWeight.w400,
  );
}
```

- [ ] **Step 4: Rewrite `app_theme.dart`**

```dart
// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:sat_east_client/core/theme/booklet_colors.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/core/theme/booklet_type.dart';

/// "The Teacher's Booklet" theme (F-4). Tokens: docs/design/claude-design-export.
abstract final class AppTheme {
  static ThemeData light() => _build(BookletSchemes.light, BookletColors.light);

  static ThemeData dark() => _build(BookletSchemes.dark, BookletColors.dark);

  static ThemeData _build(ColorScheme scheme, BookletColors booklet) {
    final text = BookletType.textTheme().apply(
      fontFamily: BookletFonts.sans,
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    const radiusXs = BorderRadius.all(Radius.circular(BookletRadius.xs));
    const radiusSm = BorderRadius.all(Radius.circular(BookletRadius.sm));
    const radiusMd = Radius.circular(BookletRadius.md);
    const buttonShape = RoundedRectangleBorder(borderRadius: radiusSm);
    const minButton = Size(64, BookletSize.touchTarget);
    const buttonPadding = EdgeInsets.symmetric(horizontal: BookletSpace.s6);
    // One shadow in light (dialog, sheet, snackbar); none in dark.
    final overlayElevation = scheme.brightness == Brightness.light ? 2.0 : 0.0;
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: radiusSm,
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      colorScheme: scheme,
      fontFamily: BookletFonts.sans,
      fontFamilyFallback: const [BookletFonts.arabic],
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: NoSplash.splashFactory,
      extensions: [booklet],
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: minButton,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: minButton,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: text.labelLarge,
          side: BorderSide(color: scheme.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: minButton,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(BookletSize.touchTarget),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: border(scheme.outline),
        enabledBorder: border(scheme.outline),
        focusedBorder: border(scheme.primary, 2),
        errorBorder: border(scheme.error),
        focusedErrorBorder: border(scheme.error, 2),
        disabledBorder: border(booklet.inkDisabled),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        surfaceTintColor: scheme.surfaceTint,
        shape: RoundedRectangleBorder(
          borderRadius: radiusXs,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: scheme.surfaceTint,
        elevation: overlayElevation,
        shadowColor: booklet.overlayShadow,
        barrierColor: booklet.scrim,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(radiusMd),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: scheme.surfaceTint,
        elevation: overlayElevation,
        modalElevation: overlayElevation,
        shadowColor: booklet.overlayShadow,
        modalBarrierColor: booklet.scrim,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: radiusMd),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: overlayElevation,
        shape: const RoundedRectangleBorder(borderRadius: radiusSm),
      ),
    );
  }
}
```

- [ ] **Step 5: Run to verify it passes**

Run: `flutter test` (whole suite; `test/widget_test.dart` must still pass). Then `dart format .`, `flutter analyze --fatal-infos` → clean. If an analyzer lint objects (e.g. `lines_longer_than_80_chars`), fix formatting only.

- [ ] **Step 6: Visual check**

`flutter run -d chrome --dart-define-from-file=env/dev.json`: placeholder screen text renders in Noto Sans (not Roboto), background `#FFFFFF`. Switch OS to dark → background `#11141A`.

- [ ] **Step 7: Commit + PR** (`git-expert`)

Commit: `feat(F-4): booklet typography and AppTheme`. PR to `main`, title `feat(F-4): theme and design tokens`, body: what ships (tokens, colors, type, fonts), spike verdict summary, tests run. Run `/flutter-code-quality:review-gate` then `/flutter-code-review` before opening; offer `code-reviewer`.

---

## Task 5: `MathText` (math + mixed-direction text)

PR "feat(F-4): MathText" on branch `feat/F-4-math-text` from `main` (after the theme PR merges). Assumes spike verdict PASS.

**Files:**
- Modify: `apps/client/pubspec.yaml` (`flutter pub add flutter_math_fork:^0.7.4`)
- Create: `apps/client/lib/core/text/text_direction.dart`
- Create: `apps/client/lib/core/math_render/math_markup.dart` (pure Dart)
- Create: `apps/client/lib/core/math_render/math_text.dart`
- Test: `apps/client/test/core/text/text_direction_test.dart`, `apps/client/test/core/math_render/math_markup_test.dart`, `apps/client/test/core/math_render/math_text_test.dart`

**Interfaces:**
- Consumes: `BookletType.{arabic,mathScale}`, `BookletSpace.s2`, `BookletSize.blockMathMinHeight`, `AppTheme.light()` (tests).
- Produces: `TextDirection detectTextDirection(String text, {TextDirection fallback})`; sealed `MathSegment` with `TextRun(String text, {bool bold})`, `InlineMath(String tex)`, `BlockMath(List<String> chunks)`; `List<MathSegment> parseMathMarkup(String source)`; widget `MathText(String source, {TextStyle? style})`. Later tasks render every stem, choice, explanation and margin note through `MathText` only.

- [ ] **Step 1: Failing tests for direction** (via `test-writer`)

```dart
// test/core/text/text_direction_test.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/text/text_direction.dart';

void main() {
  test('F-4: English text is LTR', () {
    expect(detectTextDirection('Solve for x'), TextDirection.ltr);
  });
  test('F-4: Arabic text is RTL', () {
    expect(detectTextDirection('لدينا المعادلة'), TextDirection.rtl);
  });
  test('F-4: first strong letter decides (digits and symbols skipped)', () {
    expect(detectTextDirection('12 + لدينا x'), TextDirection.rtl);
    expect(detectTextDirection('(3) Then لدينا'), TextDirection.ltr);
  });
  test('F-4: no strong letter falls back', () {
    expect(detectTextDirection('123 = 4'), TextDirection.ltr);
    expect(
      detectTextDirection('', fallback: TextDirection.rtl),
      TextDirection.rtl,
    );
  });
}
```

- [ ] **Step 2: Failing tests for the parser** (via `test-writer`)

```dart
// test/core/math_render/math_markup_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/math_render/math_markup.dart';

void main() {
  test('F-4: plain text is one run', () {
    expect(parseMathMarkup('Hello'), [const TextRun('Hello')]);
  });
  test('F-4: inline math splits the text', () {
    expect(parseMathMarkup(r'If \(x+1\) is 3'), [
      const TextRun('If '),
      const InlineMath('x+1'),
      const TextRun(' is 3'),
    ]);
  });
  test('F-4: block math becomes a block', () {
    expect(parseMathMarkup(r'Solve \[\frac{1}{x}=2\] now'), [
      const TextRun('Solve '),
      const BlockMath([r'\frac{1}{x}=2']),
      const TextRun(' now'),
    ]);
  });
  test('F-4: || splits a block into wrap chunks', () {
    expect(parseMathMarkup(r'\[a=b || c=d ||e\]'), [
      const BlockMath(['a=b', 'c=d', 'e']),
    ]);
  });
  test('F-4: **bold** toggles bold runs, also around math', () {
    expect(parseMathMarkup(r'**Rule \(x\) here** done'), [
      const TextRun('Rule ', bold: true),
      const InlineMath('x'),
      const TextRun(' here', bold: true),
      const TextRun(' done'),
    ]);
  });
  test('F-4: unclosed delimiters stay literal', () {
    expect(parseMathMarkup(r'cost \(x'), [const TextRun(r'cost \(x')]);
    expect(parseMathMarkup(r'a \[b'), [const TextRun(r'a \[b')]);
    expect(parseMathMarkup('2 ** 3'), [const TextRun('2 ** 3')]);
  });
  test('F-4: empty math is dropped', () {
    expect(parseMathMarkup(r'a\(\)b'), [const TextRun('a'), const TextRun('b')]);
  });
}
```

- [ ] **Step 3: Failing widget tests** (via `test-writer`)

```dart
// test/core/math_render/math_text_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/math_render/math_text.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';

Future<void> pumpMath(
  WidgetTester tester,
  String source, {
  double width = 1280,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: Scaffold(body: SingleChildScrollView(child: MathText(source))),
      ),
    ),
  );
}

void main() {
  testWidgets('F-4: inline TeX renders through flutter_math', (tester) async {
    await pumpMath(tester, r'If \(2x+3=11\), find x.');
    expect(find.byType(Math), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('F-4: invalid TeX falls back to its source', (tester) async {
    await pumpMath(tester, r'Bad \(\frac{\) here');
    expect(find.text(r'\frac{'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('F-4: Arabic paragraph is RTL, math stays LTR', (tester) async {
    await pumpMath(tester, r'لدينا المعادلة \(2x+3=11\) فما قيمة x؟');
    final paragraph = tester.widget<RichText>(find.byType(RichText).first);
    expect(paragraph.textDirection, TextDirection.rtl);
    final mathDir = tester.widget<Directionality>(
      find.ancestor(of: find.byType(Math), matching: find.byType(Directionality)).first,
    );
    expect(mathDir.textDirection, TextDirection.ltr);
  });

  testWidgets('F-4: trailing punctuation sticks to the formula', (tester) async {
    await pumpMath(tester, r'The answer is \(x=4\).');
    expect(
      find.descendant(of: find.byType(Row), matching: find.text('.')),
      findsOneWidget,
    );
  });

  testWidgets('F-4: || block wraps chunks', (tester) async {
    await pumpMath(tester, r'\[a=1 || b=2 || c=3\]');
    expect(find.byType(Wrap), findsOneWidget);
    expect(find.byType(Math), findsNWidgets(3));
  });

  testWidgets('F-4: 360 px at 2x text scale does not overflow', (tester) async {
    await pumpMath(
      tester,
      r'Solve \[\frac{3}{x-2}+\frac{5}{x+2}=\frac{4x+1}{x^2-4}+\frac{7}{x^2+4x+4}\] '
      'and explain each step in a sentence long enough to wrap twice.',
      width: 360,
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });
}
```

- [ ] **Step 4: Run to verify they fail**

Run: `flutter test test/core/text test/core/math_render` → FAIL (files missing).

- [ ] **Step 5: Implement direction detection**

```dart
// lib/core/text/text_direction.dart
import 'package:flutter/widgets.dart';

// Hebrew/Arabic blocks + Arabic presentation forms.
final _rtl = RegExp(r'[֐-ࣿיִ-﷿ﹰ-﻿]');
final _ltr = RegExp(r'[A-Za-zÀ-ɏ]');

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
```

- [ ] **Step 6: Implement the parser**

```dart
// lib/core/math_render/math_markup.dart
import 'package:equatable/equatable.dart';

/// A piece of content text: a plain/bold run or TeX math.
sealed class MathSegment extends Equatable {
  const MathSegment();
}

final class TextRun extends MathSegment {
  const TextRun(this.text, {this.bold = false});

  final String text;
  final bool bold;

  @override
  List<Object?> get props => [text, bold];
}

/// `\( ... \)` — sits inside the line.
final class InlineMath extends MathSegment {
  const InlineMath(this.tex);

  final String tex;

  @override
  List<Object?> get props => [tex];
}

/// `\[ ... \]` — own line; `||` splits it into chunks that may wrap.
final class BlockMath extends MathSegment {
  const BlockMath(this.chunks);

  final List<String> chunks;

  @override
  List<Object?> get props => [chunks];
}

/// Parses content markup: `\(..\)`, `\[..\]` (with `||`), `**bold**`.
/// Unclosed delimiters are kept as literal text; never throws.
List<MathSegment> parseMathMarkup(String source) {
  final out = <MathSegment>[];
  final buffer = StringBuffer();
  var bold = false;
  var i = 0;

  void flush() {
    if (buffer.isEmpty) return;
    out.add(TextRun(buffer.toString(), bold: bold));
    buffer.clear();
  }

  while (i < source.length) {
    if (source.startsWith(r'\(', i)) {
      final end = source.indexOf(r'\)', i + 2);
      if (end != -1) {
        flush();
        final tex = source.substring(i + 2, end).trim();
        if (tex.isNotEmpty) out.add(InlineMath(tex));
        i = end + 2;
        continue;
      }
    } else if (source.startsWith(r'\[', i)) {
      final end = source.indexOf(r'\]', i + 2);
      if (end != -1) {
        flush();
        final chunks = source
            .substring(i + 2, end)
            .split('||')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .toList();
        if (chunks.isNotEmpty) out.add(BlockMath(chunks));
        i = end + 2;
        continue;
      }
    } else if (source.startsWith('**', i) &&
        (bold || _hasClosingBold(source, i + 2))) {
      flush();
      bold = !bold;
      i += 2;
      continue;
    }
    buffer.write(source[i]);
    i++;
  }
  flush();
  return out;
}

/// An opening `**` counts only if a closing `**` follows that is not
/// immediately preceded by a space (so `2 ** 3` stays literal).
bool _hasClosingBold(String source, int from) {
  if (from < source.length && source[from] == ' ') return false;
  return source.indexOf('**', from) != -1;
}
```

- [ ] **Step 7: Implement `MathText`**

Before writing: use the spike answer "Math.tex follows text scaling by itself". If **no**, multiply the math font size by `MediaQuery.textScalerOf(context).scale(1)` in `_mathStyle` below; if **yes**, keep it as written.

```dart
// lib/core/math_render/math_text.dart
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:sat_east_client/core/math_render/math_markup.dart';
import 'package:sat_east_client/core/text/text_direction.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/core/theme/booklet_type.dart';

/// Renders content text with TeX math and mixed Arabic/English (rule 8).
/// The only widget that knows the math engine.
class MathText extends StatelessWidget {
  const MathText(this.source, {super.key, this.style});

  final String source;
  final TextStyle? style;

  static final _glue = RegExp(r'^[.,;:!?)\]»”،؛؟]+');

  @override
  Widget build(BuildContext context) {
    final segments = parseMathMarkup(source);
    final direction = detectTextDirection(
      segments.whereType<TextRun>().map((r) => r.text).join(),
    );
    var base = DefaultTextStyle.of(context).style.merge(style);
    if (direction == TextDirection.rtl) {
      base = base.merge(
        BookletType.arabic.copyWith(
          fontSize: base.fontSize,
          fontWeight: base.fontWeight,
          color: base.color,
        ),
      );
    }

    final children = <Widget>[];
    var inline = <MathSegment>[];
    void flushInline() {
      if (inline.isEmpty) return;
      children.add(
        Text.rich(
          TextSpan(style: base, children: _spans(inline, base)),
          textDirection: direction,
        ),
      );
      inline = [];
    }

    for (final s in segments) {
      if (s is BlockMath) {
        flushInline();
        children.add(_BlockMathView(chunks: s.chunks, style: base));
      } else {
        inline.add(s);
      }
    }
    flushInline();

    return Directionality(
      textDirection: direction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: BookletSpace.s2,
        children: children,
      ),
    );
  }

  List<InlineSpan> _spans(List<MathSegment> source, TextStyle style) {
    final segs = [...source];
    final spans = <InlineSpan>[];
    for (var i = 0; i < segs.length; i++) {
      switch (segs[i]) {
        case TextRun(:final text, :final bold):
          if (text.isEmpty) continue;
          spans.add(
            TextSpan(
              text: text,
              style: bold ? const TextStyle(fontWeight: FontWeight.w600) : null,
            ),
          );
        case InlineMath(:final tex):
          String? trailing;
          if (i + 1 < segs.length) {
            final next = segs[i + 1];
            if (next is TextRun) {
              final m = _glue.firstMatch(next.text);
              if (m != null) {
                trailing = m[0];
                segs[i + 1] = TextRun(
                  next.text.substring(m.end),
                  bold: next.bold,
                );
              }
            }
          }
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: _InlineMath(tex: tex, style: style, trailing: trailing),
            ),
          );
        case BlockMath():
          break; // blocks are laid out by build()
      }
    }
    return spans;
  }
}

TextStyle _mathStyle(TextStyle style) => style.copyWith(
  fontSize: (style.fontSize ?? 16) * BookletType.mathScale,
);

Widget _tex(String tex, TextStyle style, MathStyle mathStyle) => Math.tex(
  tex,
  mathStyle: mathStyle,
  textStyle: _mathStyle(style),
  onErrorFallback: (_) => Text(tex, style: style),
);

class _InlineMath extends StatelessWidget {
  const _InlineMath({required this.tex, required this.style, this.trailing});

  final String tex;
  final TextStyle style;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final math = Directionality(
      textDirection: TextDirection.ltr,
      child: _tex(tex, style, MathStyle.text),
    );
    final punct = trailing;
    if (punct == null) return math;
    // Row follows the paragraph direction, so punctuation lands at its end.
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [math, Text(punct, style: style)],
    );
  }
}

class _BlockMathView extends StatelessWidget {
  const _BlockMathView({required this.chunks, required this.style});

  final List<String> chunks;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final Widget content = chunks.length == 1
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _tex(chunks.single, style, MathStyle.display),
          )
        : Wrap(
            spacing: (style.fontSize ?? 16) * 0.35,
            runSpacing: BookletSpace.s2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final c in chunks) _tex(c, style, MathStyle.display),
            ],
          );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: BookletSize.blockMathMinHeight,
        ),
        child: Align(alignment: Alignment.centerLeft, child: content),
      ),
    );
  }
}
```

- [ ] **Step 8: Run to verify they pass**

Run: `flutter test test/core/text test/core/math_render` → PASS. If `F-4: invalid TeX falls back` fails because `flutter_math_fork` reports the error differently, check `onErrorFallback`'s signature with `read_package_uris` (`package:flutter_math_fork/src/widgets/math.dart`) and adapt the fallback only. Then full `flutter test`, `dart format .`, `flutter analyze --fatal-infos`.

- [ ] **Step 9: Visual check on web**

Temporarily render `MathText` with the five sample stems from `QuestionView.dc.html:396-410` (lin, rat, word, slope, tri) and `lin.arabic` in the placeholder screen, run `flutter run -d chrome` at 360 and 1280, compare with `QuestionView Practice.dc.html`. Revert the temporary screen change before committing.

- [ ] **Step 10: Commit + PR** (`git-expert`)

Commit: `feat(F-4): MathText with inline/block TeX and mixed direction`. PR title `feat(F-4): MathText`. Review gate + `/flutter-code-review` first; offer `code-reviewer`.

---

## Steps 4–7: later PRs (each gets its own detailed plan via writing-plans)

Locked names so later plans and neighbours agree. Each plan starts by re-reading the spec section and the export file named.

**PR "Components A — answer inputs"** — plan `docs/superpowers/plans/2026-10-13-f4-components-inputs.md`. `ChoiceTile`, `SprInput`, `SprKeypad`, `FeedbackLabel`, `lib/core/grading/spr_editing.dart`, `painters/dashed_border.dart`, `painters/strike_through.dart`, `focus_ring.dart`, golden setup.

**PR "Components B — buttons and feedback"** — own plan (writing-plans) when reached; source `Components.dc.html` §1 and §8. `loading_button.dart`, `booklet_chip.dart`, `booklet_banner.dart` (info/warning/offline), `booklet_overlays.dart` (`showBookletDialog`, `showBookletSheet`, snackbar helper), `booklet_progress.dart`, `booklet_skeleton.dart`, `empty_state.dart`, `error_retry.dart`. Reuses the golden harness from PR A.

Scope moves (decided 2026-10-13): `Components.dc.html` §4 margin note, §6 exam bar + module time bar + review time-per-question, §7 navigator cell → PR "QuestionView". §5 explanation frames (rule box, worked example) → deferred to the review/notes work.
Goldens: test files under `test/goldens/` with `@Tags(['golden'])`; real fonts from `test/goldens/flutter_test_config.dart`; baselines generated on Windows; CI runs `flutter test --exclude-tags golden`.

**PR "App shell"** — `lib/shared/widgets/app_shell/`, source `App Shell.dc.html`.
- `AppShell` (bottom `NavigationBar` / `NavigationRail` / sidebar by `BookletLayout.forWidth`), `FocusModeScaffold` (quiz/mock, nav hidden). Wired via `StatefulShellRoute.indexedStack` in `lib/core/router/app_router.dart`; destinations stay placeholders.
- Done when: layout switch tests at 360 / 768 / 1280; existing `widget_test.dart` still passes.

**PR "QuestionView"** — `lib/shared/widgets/question_view/`, source `QuestionView*.dc.html`.
- `QuestionView`, sealed `QuestionViewMode` (`PracticeMode`, `HomeworkMode`, `QuizMode`, `MockMode`, `ReviewMode`), `QuestionData` (no answer-key field), `TimerData`, `NavigatorData`, `QuestionFeedback`; exam bar, light header, footer, navigator popover/side panel/sheet, teacher's margin, mock review-before-submit page, time-up and exit dialogs; `Shortcuts`/`Actions` (A–D, Shift+A–D, M, arrows). Clock injected.
- Done when: one widget test per mode for chrome + callbacks; a test that `QuestionData` exposes no key/explanation field; goldens per mode at 360 + 1280.

**PR "Gallery"** — `lib/features/design_gallery/presentation/` (presentation only, static sample data from `QuestionView.dc.html:396-410`).
- Route `/gallery` added in `app_router.dart` only when `Env.flavor != Flavor.prod`.
- Done when: every mode and state viewable on Chrome at 360 and 1280; deployed to staging by CI; `docs/15` row 6 marked done.

---

## Verification (whole plan)
- Per task: the listed test command, then `dart format .` → no changes, `flutter analyze --fatal-infos` → clean, `flutter test` → all pass (from `apps/client/`).
- Per PR: `/flutter-code-quality:review-gate`, `/flutter-code-review`, offer `code-reviewer`; CI green (`gh pr checks --watch`).
- End of Task 5: Chrome at 360 and 1280 shows the sample stems matching `QuestionView Practice.dc.html` (math on baseline, Arabic paragraph RTL, no overflow).
- After merge: `graphify update .` (CLAUDE.md).

## Execution
Recommended: **subagent-driven** — each task to an `implementer` agent (tests via `test-writer`, git via `git-expert`), router reviews each diff and test run before the next task (user's routing rule). Task 1 is a gate: stop and report its verdict before Task 2.
