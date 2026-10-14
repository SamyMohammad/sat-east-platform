# F-4 Components A — answer inputs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the answer-input components of the booklet design system — `ChoiceTile`, `SprInput`, `SprKeypad` — plus the painters, focus ring and golden-test setup they need, matching `Components.dc.html` §2–§3.

**Architecture:** Widgets in `lib/shared/widgets/` take data + callbacks only (no Cubit, no Supabase). SPR editing rules (keypad keys, digit normalisation, preview TeX) are pure Dart in `lib/core/grading/spr_editing.dart` next to the existing `parseSprAnswer`. Every visual value comes from `Theme.of(context)`, `context.booklet` or the token classes in `booklet_tokens.dart` (extended in Task 1). Goldens use plain `matchesGoldenFile` with real fonts loaded from `FontManifest.json`, tagged `golden`, excluded on CI.

**Tech Stack:** Flutter 3.44.1 / Dart ^3.12.1, `flutter_math_fork` 0.7.4 (via `MathText` only), `flutter_test`. No new packages.

**Spec:** `docs/superpowers/specs/2026-10-13-f4-design-system-questionview-design.md` §2. Parent plan: `docs/superpowers/plans/2026-10-13-f4-design-system.md` ("Steps 4–7"). Design source: `docs/design/claude-design-export/Components.dc.html` lines 91–216 (light), `Components Dark.dc.html` (same sheet, dark tokens).

## Context

### Continuation on 2026-10-14

Tasks 0–3 are present in commits `79d948e` through `b3f76ee` on
`feat/F-4-components-inputs`. The remaining implementation uses
`lib/core/widgets/` for new SPR components and `test/core/widgets/` for their
tests, following the current AGENTS.md shared-component rule. Existing
`ChoiceTile`, painters and `FeedbackLabel` keep their paths.

Implementation adjustments: single-line submission, composing-text-safe
formatting, external focus ownership, adaptive review labels at 2× text size,
keyboard-operable keypad keys, and a zero key aligned to two grid columns.
Visual review also found and fixed double scaling of inline math in
`MathText` (WidgetSpan and the math engine both applied text scaling), and
ensured the answer preview sits beside the field when space permits.
The golden matrix has 13 images, including 2× SPR input and keypad variants.
Goldens use real bundled fonts and stay excluded on Linux CI.

The remaining snippets below describe the original plan; the path and layout
adjustments in this continuation take precedence. Commit/push/PR wait for the
user's approval of the completed change.

Tasks 4–6 are implemented and locally verified: 192 unit/widget tests and
13 Windows golden tests pass. All golden PNGs were opened and reviewed.
The independent branch review has no remaining material findings.
The generic review-gate script misidentifies `BookletSpace.s3` as a numeric
EdgeInsets literal; both reported locations use the existing spacing token.
Next: approval and PR for Components A, then plan Components B (buttons and
feedback). Chrome gallery/staging validation belongs to the later gallery PR.
Row 6 of `docs/15` §1 (F-4). Theme + tokens (PR #13) and `MathText` (PR #15) are merged. `lib/shared/widgets/` is empty. Brainstorm quick pass (2026-10-13) decided:
1. Components PR covers `Components.dc.html` §1–3 + §8. §4 margin note, §6 exam bar / time bars, §7 navigator cell move to the QuestionView PR. §5 explanation frames are deferred to the review/notes work.
2. Split into two PRs: **A = answer inputs (this plan)**, B = buttons + feedback (chips, banners, overlays, progress, skeleton, empty, error-retry, loading button) — its own plan later.
3. Goldens: tagged `golden`, real fonts, baselines generated on Windows, CI runs `flutter test --exclude-tags golden`.

## Global Constraints
- Branch `feat/F-4-components-inputs` from an up-to-date `main`. Git via `git-expert` agent.
- CLAUDE.md A.1–A.7, B.1–B.9. `very_good_analysis`. No `freezed`/`json_serializable`/`build_runner`. `const` wherever possible.
- No hard-coded colors, sizes, durations in widgets. Export → role map (use exactly these):

| Export var | Flutter role |
|---|---|
| `--page`, `--surface` | `colorScheme.surface` |
| `--surface2` | `colorScheme.surfaceContainer` |
| `--ink` | `colorScheme.onSurface` |
| `--ink2` | `colorScheme.onSurfaceVariant` |
| `--ink3` | `context.booklet.inkDisabled` |
| `--rule` | `colorScheme.outlineVariant` |
| `--rule2` | `colorScheme.outline` |
| `--primary` / `--onp` | `colorScheme.primary` / `onPrimary` |
| `--pc` | `colorScheme.primaryContainer` |
| `--red` / `--redc` | `colorScheme.error` / `errorContainer` |
| `--green` / `--greenc` | `booklet.greenTick` / `booklet.greenTickContainer` |
| `--info` | `booklet.info` |

- Icons: Material `Icons.*_rounded` / `*_outlined` (no Material Symbols font). FILL 1 → `*_rounded`, FILL 0 → `*_outline_rounded` / `*_outlined`.
- UI copy is English (rule 8); choice content renders through `MathText` only.
- Rule 1: widgets display feedback states they are given; they never compute correctness.
- Test names start with `F-4:`. `*_test.dart` files are written by the `test-writer` agent with the content given here.
- Before each commit (from `apps/client/`): `dart format .`, `flutter analyze --fatal-infos`, `flutter test` clean.
- Commits end with a blank line + `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Golden PNGs: open and look at every new/changed PNG before committing (golden-tests skill rule).

## Review Focus
1. Hints must be reachable: typing `1 1/2` (space) and `0.66667` (7 chars) must reach the field so the mixed-number and length hints show — no space filter, no 5-char limit. Pinned in Task 4.
2. Arabic-Indic digits from a hardware keyboard (`٣/٤`, `۱.۵`) and U+2212 minus → normalised to ASCII before the parser. Pinned in Tasks 1 and 4.
3. Keypad "−" key (label U+2212) inserts ASCII `-` and toggles; second `/` or `.` and mixing `/` with `.` are refused with a hint. Pinned in Task 1.
4. Two-line choice at 360 px and text scale 2.0 → no overflow; tile height identical across idle / selected / feedback states (no 1→2 px border jump). Pinned in Task 3.
5. Keypad under an RTL ambient `Directionality` keeps LTR key order (1 left of 3). Pinned in Task 5.

---

## Task 0: Docs + branch

**Files:**
- Create: `docs/superpowers/plans/2026-10-13-f4-components-inputs.md` (copy of this plan)
- Modify: `docs/superpowers/plans/2026-10-13-f4-design-system.md` (block `**PR "Components"**` under "Steps 4–7")
- Modify: `docs/superpowers/specs/2026-10-13-f4-design-system-questionview-design.md` (§4 Testing, §5 Delivery)

- [ ] **Step 1:** `git-expert`: `git fetch origin`, switch to `main`, `git pull --ff-only`, confirm `f74abf8` (MathText) is in `main`, create branch `feat/F-4-components-inputs`. Leave untracked `.codex/` and `.impeccable/` alone.
- [ ] **Step 2:** Copy this plan to `docs/superpowers/plans/2026-10-13-f4-components-inputs.md`.
- [ ] **Step 3:** In the parent plan, replace the whole `**PR "Components"**` block (4 bullets) with:

```markdown
**PR "Components A — answer inputs"** — plan `docs/superpowers/plans/2026-10-13-f4-components-inputs.md`. `ChoiceTile`, `SprInput`, `SprKeypad`, `FeedbackLabel`, `lib/core/grading/spr_editing.dart`, `painters/dashed_border.dart`, `painters/strike_through.dart`, `focus_ring.dart`, golden setup.

**PR "Components B — buttons and feedback"** — own plan (writing-plans) when reached; source `Components.dc.html` §1 and §8. `loading_button.dart`, `booklet_chip.dart`, `booklet_banner.dart` (info/warning/offline), `booklet_overlays.dart` (`showBookletDialog`, `showBookletSheet`, snackbar helper), `booklet_progress.dart`, `booklet_skeleton.dart`, `empty_state.dart`, `error_retry.dart`. Reuses the golden harness from PR A.

Scope moves (decided 2026-10-13): `Components.dc.html` §4 margin note, §6 exam bar + module time bar + review time-per-question, §7 navigator cell → PR "QuestionView". §5 explanation frames (rule box, worked example) → deferred to the review/notes work.
Goldens: test files under `test/goldens/` with `@Tags(['golden'])`; real fonts from `test/goldens/flutter_test_config.dart`; baselines generated on Windows; CI runs `flutter test --exclude-tags golden`.
```

- [ ] **Step 4:** In the spec, §4 Testing, replace the `- Golden:` line with:

```markdown
- Golden: components and `QuestionView` at 360 and 1280 (light; dark for components), one 2.0 text-scale variant per component. Tagged `golden`, baselines generated on Windows, excluded on CI (`flutter test --exclude-tags golden`) because Linux font rasterisation differs.
```

and in §5 Delivery replace `3. Components.` with:

```markdown
3. Components, in two PRs: A answer inputs (`ChoiceTile`, `SprInput`, `SprKeypad`), B buttons and feedback. Margin note, exam bar and navigator cell ship with `QuestionView`; explanation frames are deferred to the review/notes work.
```

- [ ] **Step 5:** Commit (`git-expert`): `docs(F-4): split components PR and record golden strategy`.

---

## Task 1: Tokens + SPR editing rules (pure Dart)

**Files:**
- Modify: `apps/client/lib/core/theme/booklet_tokens.dart` (`BookletSize`; add `BookletStroke`, `BookletOpacity`)
- Create: `apps/client/lib/core/grading/spr_editing.dart`
- Test: `apps/client/test/core/theme/booklet_tokens_test.dart` (add one test), `apps/client/test/core/grading/spr_editing_test.dart`

**Interfaces:**
- Consumes: `parseSprAnswer`, `SprValid`, `sprMaxLengthNegative` from `lib/core/grading/spr_answer.dart`.
- Produces:
  - `BookletSize.{largeControl=56, choiceBadge=28, sprInputWidth=200, iconSmall=20, iconStatus=18}` (double).
  - `BookletStroke.{thin=1, badge=1.5, strong=2, strike=1.5, focusRing=2, focusGap=2, dash=4, dashGap=3}` (double).
  - `BookletOpacity.eliminated = 0.6`.
  - `enum SprKey { zero … nine, slash, dot, minus, backspace }` with `String? char` and `static SprKey digit(int n)`.
  - `enum SprKeyHint { secondSlash, secondDot, slashAndDot }`.
  - `typedef SprEdit = ({String text, SprKeyHint? hint});`
  - `SprEdit applySprKey(String text, SprKey key)`.
  - `String normalizeSprDigits(String input)`.
  - `const int sprInputMaxChars = 8`.
  - `String? sprPreviewTex(String input)`.

- [ ] **Step 1: Write the failing tests** (via `test-writer`)

Add to `test/core/theme/booklet_tokens_test.dart` inside `main()`:

```dart
  test('F-4: answer controls are 56 and the badge centres in a 48 row', () {
    expect(BookletSize.largeControl, 56);
    expect((BookletSize.touchTarget - BookletSize.choiceBadge) / 2, 10);
    expect(BookletStroke.strong - BookletStroke.thin, 1);
  });
```

Create `test/core/grading/spr_editing_test.dart`:

```dart
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
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/core/theme/booklet_tokens_test.dart test/core/grading/spr_editing_test.dart`
Expected: FAIL — `BookletStroke` undefined, `spr_editing.dart` not found.

- [ ] **Step 3: Extend tokens** — in `lib/core/theme/booklet_tokens.dart` replace `BookletSize` and add two classes after it:

```dart
/// Fixed sizes shared by many widgets.
abstract final class BookletSize {
  static const double touchTarget = 48;

  /// Choice tile min height, SPR field height, keypad key height.
  static const double largeControl = 56;
  static const double choiceBadge = 28;
  static const double sprInputWidth = 200;
  static const double iconSmall = 20;
  static const double iconStatus = 18;
  static const double readingColumn = 640;
  static const double questionColumn = 720;
  static const double blockMathMinHeight = 64;
}

/// Line widths (Components.dc.html borders, outlines, strike).
abstract final class BookletStroke {
  static const double thin = 1;
  static const double badge = 1.5;
  static const double strong = 2;
  static const double strike = 1.5;
  static const double focusRing = 2;
  static const double focusGap = 2;
  static const double dash = 4;
  static const double dashGap = 3;
}

/// Opacity roles.
abstract final class BookletOpacity {
  /// Text of a crossed-out choice.
  static const double eliminated = 0.6;
}
```

- [ ] **Step 4: Implement `spr_editing.dart`**

```dart
/// SPR editing rules for the custom keypad and the text field (F-4).
/// Input only — grading stays server-side.
library;

import 'package:sat_east_client/core/grading/spr_answer.dart';

/// Hard cap on typed characters. Above the 6-char grading rule on purpose,
/// so the "too long" hint can still show.
const int sprInputMaxChars = sprMaxLengthNegative + 2;

/// A key on the SPR keypad.
enum SprKey {
  zero('0'),
  one('1'),
  two('2'),
  three('3'),
  four('4'),
  five('5'),
  six('6'),
  seven('7'),
  eight('8'),
  nine('9'),
  slash('/'),
  dot('.'),
  minus('-'),
  backspace(null);

  const SprKey(this.char);

  /// Character the key inserts (ASCII); null for actions.
  final String? char;

  static SprKey digit(int n) => values[n];
}

/// Why a keypad key was ignored.
enum SprKeyHint { secondSlash, secondDot, slashAndDot }

typedef SprEdit = ({String text, SprKeyHint? hint});

/// Applies one keypad [key] to [text].
SprEdit applySprKey(String text, SprKey key) {
  if (key == SprKey.backspace) {
    return (
      text: text.isEmpty ? text : text.substring(0, text.length - 1),
      hint: null,
    );
  }
  if (key == SprKey.minus) {
    return (
      text: text.startsWith('-') ? text.substring(1) : '-$text',
      hint: null,
    );
  }
  if (key == SprKey.slash) {
    if (text.contains('/')) return (text: text, hint: SprKeyHint.secondSlash);
    if (text.contains('.')) return (text: text, hint: SprKeyHint.slashAndDot);
  }
  if (key == SprKey.dot) {
    if (text.contains('.')) return (text: text, hint: SprKeyHint.secondDot);
    if (text.contains('/')) return (text: text, hint: SprKeyHint.slashAndDot);
  }
  if (text.length >= sprInputMaxChars) return (text: text, hint: null);
  return (text: '$text${key.char}', hint: null);
}

/// Maps Arabic-Indic / Persian digits, the Arabic decimal separator and
/// U+2212 minus to ASCII. One UTF-16 unit in, one out (keeps selections valid).
String normalizeSprDigits(String input) {
  final out = StringBuffer();
  for (final unit in input.codeUnits) {
    if (unit >= 0x0660 && unit <= 0x0669) {
      out.writeCharCode(0x30 + unit - 0x0660);
    } else if (unit >= 0x06F0 && unit <= 0x06F9) {
      out.writeCharCode(0x30 + unit - 0x06F0);
    } else if (unit == 0x066B) {
      out.write('.');
    } else if (unit == 0x2212) {
      out.write('-');
    } else {
      out.writeCharCode(unit);
    }
  }
  return out.toString();
}

/// TeX for the Answer Preview, built from the typed text (not reduced, like
/// the official preview). Null until [input] parses as a valid answer.
String? sprPreviewTex(String input) {
  if (parseSprAnswer(input) is! SprValid) return null;
  final s = input.trim();
  final sign = s.startsWith('-') ? '-' : '';
  final body = s.substring(sign.length);
  final slash = body.indexOf('/');
  if (slash == -1) return '$sign$body';
  return '$sign\\dfrac{${body.substring(0, slash)}}'
      '{${body.substring(slash + 1)}}';
}
```

- [ ] **Step 5: Run to verify they pass** — same command → PASS. Then `dart format .`, `flutter analyze --fatal-infos`, `flutter test`.
- [ ] **Step 6: Commit**: `feat(F-4): answer-control tokens and SPR editing rules`

---

## Task 2: Painters + focus ring

**Files:**
- Create: `apps/client/lib/shared/widgets/painters/dashed_border.dart`
- Create: `apps/client/lib/shared/widgets/painters/strike_through.dart`
- Create: `apps/client/lib/shared/widgets/focus_ring.dart`
- Test: `apps/client/test/shared/widgets/painters_test.dart`

**Interfaces:**
- Consumes: `BookletStroke`, `BookletSpace.s1`, `BookletMotion.{base,standard,resolve}`.
- Produces:
  - `DashedBorderPainter({required Color color, required double radius, double strokeWidth, double dash, double gap})` — `CustomPainter`, use as `foregroundPainter`.
  - `StrikeThrough({required bool struck, required Color color, required Widget child})` — animates a line across the child over `BookletMotion.base` (reduced motion via `resolve`). Painter `StrikeThroughPainter` exposes `Animation<double> progress`.
  - `FocusRing({required bool visible, required double borderRadius, required Widget child})`; `FocusRingPainter.ringRect(Size) → Rect` (child rect inflated by `focusGap + focusRing / 2`). Paints outside the child; callers keep ≥ `BookletSpace.s1` free space around it.

- [ ] **Step 1: Write the failing tests** (via `test-writer`)

```dart
// test/shared/widgets/painters_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/shared/widgets/focus_ring.dart';
import 'package:sat_east_client/shared/widgets/painters/dashed_border.dart';
import 'package:sat_east_client/shared/widgets/painters/strike_through.dart';

Widget _host(Widget child, {bool reduced = false}) => MaterialApp(
  theme: AppTheme.light(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Center(child: SizedBox(width: 200, height: 56, child: child)),
  ),
);

double _progress(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(StrikeThrough),
      matching: find.byType(CustomPaint),
    ),
  );
  return (paint.foregroundPainter! as StrikeThroughPainter).progress.value;
}

void main() {
  testWidgets('F-4: strike starts drawn when struck initially', (t) async {
    await t.pumpWidget(
      _host(const StrikeThrough(struck: true, color: Colors.black, child: SizedBox.expand())),
    );
    expect(_progress(t), 1);
  });

  testWidgets('F-4: strike animates in over motion.base', (t) async {
    Widget build(bool struck) => _host(
      StrikeThrough(struck: struck, color: Colors.black, child: const SizedBox.expand()),
    );
    await t.pumpWidget(build(false));
    expect(_progress(t), 0);
    await t.pumpWidget(build(true));
    await t.pump(BookletMotion.base ~/ 2);
    expect(_progress(t), inExclusiveRange(0, 1));
    await t.pump(BookletMotion.base);
    expect(_progress(t), 1);
  });

  testWidgets('F-4: reduced motion finishes the strike within motion.fast', (t) async {
    Widget build(bool struck) => _host(
      StrikeThrough(struck: struck, color: Colors.black, child: const SizedBox.expand()),
      reduced: true,
    );
    await t.pumpWidget(build(false));
    await t.pumpWidget(build(true));
    await t.pump(BookletMotion.fast);
    expect(_progress(t), 1);
  });

  test('F-4: dashed border repaints only when its look changes', () {
    const a = DashedBorderPainter(color: Colors.black, radius: 4);
    expect(a.shouldRepaint(const DashedBorderPainter(color: Colors.black, radius: 4)), isFalse);
    expect(a.shouldRepaint(const DashedBorderPainter(color: Colors.red, radius: 4)), isTrue);
  });

  testWidgets('F-4: dashed border paints without error', (t) async {
    await t.pumpWidget(
      _host(const CustomPaint(foregroundPainter: DashedBorderPainter(color: Colors.black, radius: 4))),
    );
    expect(t.takeException(), isNull);
  });

  test('F-4: focus ring sits 2 px outside the child', () {
    final rect = FocusRingPainter.ringRect(const Size(100, 50));
    const outset = BookletStroke.focusGap + BookletStroke.focusRing / 2;
    expect(rect, const Rect.fromLTRB(-outset, -outset, 100 + outset, 50 + outset));
  });

  testWidgets('F-4: focus ring paints only when visible', (t) async {
    Future<CustomPainter?> painter(bool visible) async {
      await t.pumpWidget(
        _host(FocusRing(visible: visible, borderRadius: 4, child: const SizedBox.expand())),
      );
      return t
          .widget<CustomPaint>(find.descendant(of: find.byType(FocusRing), matching: find.byType(CustomPaint)))
          .foregroundPainter;
    }

    expect(await painter(false), isNull);
    expect(await painter(true), isA<FocusRingPainter>());
  });
}
```

- [ ] **Step 2: Run to verify they fail** — `flutter test test/shared/widgets/painters_test.dart` → FAIL (files missing).

- [ ] **Step 3: Implement `dashed_border.dart`**

```dart
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';

/// Dashed rounded-rect outline (eliminated choice, Components.dc.html §2).
class DashedBorderPainter extends CustomPainter {
  const DashedBorderPainter({
    required this.color,
    required this.radius,
    this.strokeWidth = BookletStroke.thin,
    this.dash = BookletStroke.dash,
    this.gap = BookletStroke.dashGap,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + dash, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dash != dash ||
      oldDelegate.gap != gap;
}
```

- [ ] **Step 4: Implement `strike_through.dart`**

```dart
import 'package:flutter/widgets.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';

/// Draws a line through [child] when [struck], animated over motion.base
/// (reduced motion: motion.fast). Line overhangs the start by space.s1 and
/// stops space.s1 short of the end (Components.dc.html §2 eliminated).
class StrikeThrough extends StatefulWidget {
  const StrikeThrough({
    required this.struck,
    required this.color,
    required this.child,
    super.key,
  });

  final bool struck;
  final Color color;
  final Widget child;

  @override
  State<StrikeThrough> createState() => _StrikeThroughState();
}

class _StrikeThroughState extends State<StrikeThrough>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: widget.struck ? 1 : 0,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: BookletMotion.standard,
  );

  @override
  void didUpdateWidget(StrikeThrough oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.struck == widget.struck) return;
    _controller.duration = BookletMotion.resolve(context, BookletMotion.base);
    if (widget.struck) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: StrikeThroughPainter(
        progress: _curve,
        color: widget.color,
        textDirection: Directionality.of(context),
      ),
      child: widget.child,
    );
  }
}

class StrikeThroughPainter extends CustomPainter {
  StrikeThroughPainter({
    required this.progress,
    required this.color,
    required this.textDirection,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final Color color;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t == 0) return;
    final y = size.height / 2;
    final length = size.width * t;
    final paint = Paint()
      ..color = color
      ..strokeWidth = BookletStroke.strike;
    if (textDirection == TextDirection.ltr) {
      const start = -BookletSpace.s1;
      canvas.drawLine(Offset(start, y), Offset(start + length, y), paint);
    } else {
      final start = size.width + BookletSpace.s1;
      canvas.drawLine(Offset(start, y), Offset(start - length, y), paint);
    }
  }

  @override
  bool shouldRepaint(StrikeThroughPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.textDirection != textDirection ||
      oldDelegate.progress != progress;
}
```

- [ ] **Step 5: Implement `focus_ring.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';

/// Keyboard focus outline: 2 px primary, 2 px outside the child (Foundations
/// focus rule). Paints outside its box; keep space.s1 free around it.
class FocusRing extends StatelessWidget {
  const FocusRing({
    required this.visible,
    required this.borderRadius,
    required this.child,
    super.key,
  });

  final bool visible;
  final double borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: visible
          ? FocusRingPainter(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: borderRadius,
            )
          : null,
      child: child,
    );
  }
}

class FocusRingPainter extends CustomPainter {
  const FocusRingPainter({required this.color, required this.borderRadius});

  final Color color;
  final double borderRadius;

  static const double _outset =
      BookletStroke.focusGap + BookletStroke.focusRing / 2;

  /// Centre line of the ring stroke for a child of [size].
  static Rect ringRect(Size size) => (Offset.zero & size).inflate(_outset);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        ringRect(size),
        Radius.circular(borderRadius + _outset),
      ),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = BookletStroke.focusRing,
    );
  }

  @override
  bool shouldRepaint(FocusRingPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.borderRadius != borderRadius;
}
```

- [ ] **Step 6: Run to verify they pass** — test PASS; format; analyze; full `flutter test`.
- [ ] **Step 7: Commit**: `feat(F-4): dashed border, strike-through and focus ring painters`

---

## Task 3: `FeedbackLabel` + `ChoiceTile`

**Files:**
- Create: `apps/client/lib/shared/widgets/feedback_label.dart`
- Create: `apps/client/lib/shared/widgets/choice_tile.dart`
- Test: `apps/client/test/shared/widgets/choice_tile_test.dart`

**Interfaces:**
- Consumes: Task 1 tokens, Task 2 `DashedBorderPainter`, `StrikeThrough`, `FocusRing`; `MathText(String source, {TextStyle? style})`; `context.booklet`.
- Produces:
  - `FeedbackLabel({required IconData icon, required String label, required Color color})` — 18 px icon + 12/600 label. Reused by `SprInput` and later the navigator.
  - `enum ChoiceTileState { idle, selected, eliminated, disabled, correct, incorrect, yourAnswerWrong, correctAnswer, yourAnswerCorrect, reviewOther }`
  - `ChoiceTile({required String letter, required String content, required ChoiceTileState state, VoidCallback? onSelect, VoidCallback? onEliminate, VoidCallback? onRestore})`. Selectable only in `idle`/`selected` with `onSelect != null`. Cross-out button shows in `idle`/`selected` when `onEliminate != null`. "Undo" shows in `eliminated` when `onRestore != null`. Semantics: radio (`inMutuallyExclusiveGroup`, `checked`), label `Choice <letter>`.

State → look (from `Components.dc.html:94-136`):

| State | Fill | Border | Badge | Trailing |
|---|---|---|---|---|
| idle | surface (hover: surfaceContainer) | 1 outlineVariant (hover: inkDisabled) | 1.5 outline, onSurface | cross-out |
| selected | primaryContainer | 2 primary | filled primary, onPrimary | cross-out |
| eliminated | surface | 1 dashed outlineVariant | 1.5 inkDisabled; text inkDisabled @ 0.6; strike | Undo |
| disabled | surface | 1 outlineVariant | 1.5 inkDisabled, text inkDisabled | — |
| correct | greenTickContainer | 2 greenTick | filled greenTick, surface | ● check "Correct" |
| incorrect | errorContainer | 2 error | filled error, surface | ● cancel "Incorrect" |
| yourAnswerWrong | errorContainer | 2 error | filled error, surface | ● cancel "Your answer" |
| correctAnswer | surface | 2 greenTick | 2 greenTick outline, greenTick w700 | ○ check "Correct answer" |
| yourAnswerCorrect | greenTickContainer | 2 greenTick | filled greenTick, surface | ● check "Your answer · Correct" |
| reviewOther | surface | 1 outlineVariant | 1.5 inkDisabled, text onSurfaceVariant | — |

Border is a `foregroundDecoration` (does not move content), so all states share one size. Padding = export padding + 1 px border: start/top/bottom `s3+thin` / `s1+thin`; end `thin` beside a button, `s3+thin` otherwise. Badge and trailing are top-aligned in a 48 px row (badge offset 10), so one- and two-line choices both match the export.

- [ ] **Step 1: Write the failing tests** (via `test-writer`)

```dart
// test/shared/widgets/choice_tile_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/shared/widgets/choice_tile.dart';
import 'package:sat_east_client/shared/widgets/focus_ring.dart';

Future<void> pumpTile(
  WidgetTester tester,
  ChoiceTile tile, {
  double width = 720,
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
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(BookletSpace.s4),
            child: Column(children: [tile]),
          ),
        ),
      ),
    ),
  );
}

ChoiceTile tile(
  ChoiceTileState state, {
  VoidCallback? onSelect,
  VoidCallback? onEliminate,
  VoidCallback? onRestore,
  String content = r'\(x = 3\)',
}) => ChoiceTile(
  letter: 'B',
  content: content,
  state: state,
  onSelect: onSelect,
  onEliminate: onEliminate,
  onRestore: onRestore,
);

void main() {
  testWidgets('F-4: tapping an idle tile selects it', (t) async {
    var taps = 0;
    await pumpTile(t, tile(ChoiceTileState.idle, onSelect: () => taps++));
    await t.tap(find.byType(ChoiceTile));
    expect(taps, 1);
  });

  testWidgets('F-4: cross-out fires onEliminate, not onSelect', (t) async {
    var selects = 0;
    var eliminates = 0;
    await pumpTile(
      t,
      tile(ChoiceTileState.selected, onSelect: () => selects++, onEliminate: () => eliminates++),
    );
    await t.tap(find.byTooltip('Cross out choice B'));
    expect((selects, eliminates), (0, 1));
  });

  testWidgets('F-4: cross-out target is 48 px', (t) async {
    await pumpTile(t, tile(ChoiceTileState.idle, onSelect: () {}, onEliminate: () {}));
    final size = t.getSize(find.byType(IconButton));
    expect(size.width, greaterThanOrEqualTo(BookletSize.touchTarget));
    expect(size.height, greaterThanOrEqualTo(BookletSize.touchTarget));
  });

  testWidgets('F-4: no cross-out without onEliminate', (t) async {
    await pumpTile(t, tile(ChoiceTileState.idle, onSelect: () {}));
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('F-4: eliminated tile restores via Undo and ignores taps', (t) async {
    var selects = 0;
    var restores = 0;
    await pumpTile(
      t,
      tile(ChoiceTileState.eliminated, onSelect: () => selects++, onRestore: () => restores++),
    );
    await t.tap(find.text('Undo'));
    await t.tapAt(t.getTopLeft(find.byType(ChoiceTile)) + const Offset(40, 20));
    expect((selects, restores), (0, 1));
  });

  testWidgets('F-4: disabled tile ignores taps and has no cross-out', (t) async {
    var selects = 0;
    await pumpTile(
      t,
      tile(ChoiceTileState.disabled, onSelect: () => selects++, onEliminate: () {}),
    );
    await t.tap(find.byType(ChoiceTile));
    expect(selects, 0);
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('F-4: keyboard Tab shows the ring and Enter selects', (t) async {
    var selects = 0;
    await pumpTile(t, tile(ChoiceTileState.idle, onSelect: () => selects++));
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    expect(t.widget<FocusRing>(find.byType(FocusRing)).visible, isTrue);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(selects, 1);
  });

  testWidgets('F-4: tile size is the same across states', (t) async {
    Future<Size> sizeOf(ChoiceTileState s) async {
      await pumpTile(t, tile(s, onSelect: () {}, onEliminate: () {}));
      return t.getSize(find.byType(ChoiceTile));
    }

    final idle = await sizeOf(ChoiceTileState.idle);
    expect(await sizeOf(ChoiceTileState.selected), idle);
    expect((await sizeOf(ChoiceTileState.correct)).height, idle.height);
    expect((await sizeOf(ChoiceTileState.correctAnswer)).height, idle.height);
  });

  for (final (state, label, icon) in [
    (ChoiceTileState.correct, 'Correct', Icons.check_circle_rounded),
    (ChoiceTileState.incorrect, 'Incorrect', Icons.cancel_rounded),
    (ChoiceTileState.yourAnswerWrong, 'Your answer', Icons.cancel_rounded),
    (ChoiceTileState.correctAnswer, 'Correct answer', Icons.check_circle_outline_rounded),
    (ChoiceTileState.yourAnswerCorrect, 'Your answer · Correct', Icons.check_circle_rounded),
  ]) {
    testWidgets('F-4: ${state.name} shows "$label"', (t) async {
      await pumpTile(t, tile(state, onSelect: () {}, onEliminate: () {}));
      expect(find.text(label), findsOneWidget);
      expect(find.byIcon(icon), findsOneWidget);
      expect(find.byType(IconButton), findsNothing);
    });
  }

  testWidgets('F-4: selected tile is a checked radio', (t) async {
    final handle = t.ensureSemantics();
    await pumpTile(t, tile(ChoiceTileState.selected, onSelect: () {}));
    expect(
      t.getSemantics(find.byType(ChoiceTile)),
      containsSemantics(
        isInMutuallyExclusiveGroup: true,
        hasCheckedState: true,
        isChecked: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('F-4: two-line choice at 360 px and 2x text does not overflow', (t) async {
    await pumpTile(
      t,
      tile(
        ChoiceTileState.idle,
        onSelect: () {},
        onEliminate: () {},
        content: r'The line rises 3 units for each unit to the right, so its slope is \(3\).',
      ),
      width: 360,
      textScale: 2,
    );
    expect(t.takeException(), isNull);
    expect(t.getSize(find.byType(IconButton)).height, greaterThanOrEqualTo(BookletSize.touchTarget));
  });
}
```

- [ ] **Step 2: Run to verify they fail** — `flutter test test/shared/widgets/choice_tile_test.dart` → FAIL (files missing).

- [ ] **Step 3: Implement `feedback_label.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';

/// Icon + short status text ("Correct", "Your answer"), Components.dc.html.
class FeedbackLabel extends StatelessWidget {
  const FeedbackLabel({
    required this.icon,
    required this.label,
    required this.color,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: BookletSpace.s1,
      children: [
        Icon(icon, size: BookletSize.iconStatus, color: color),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: color, letterSpacing: 0),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Implement `choice_tile.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:sat_east_client/core/math_render/math_text.dart';
import 'package:sat_east_client/core/theme/booklet_colors.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/shared/widgets/feedback_label.dart';
import 'package:sat_east_client/shared/widgets/focus_ring.dart';
import 'package:sat_east_client/shared/widgets/painters/dashed_border.dart';
import 'package:sat_east_client/shared/widgets/painters/strike_through.dart';

/// What a choice tile shows. Feedback states come from the server result
/// (rule 1); the tile never decides correctness.
enum ChoiceTileState {
  idle,
  selected,
  eliminated,
  disabled,

  /// Practice: picked and right.
  correct,

  /// Practice: picked and wrong.
  incorrect,

  /// Review: picked and wrong.
  yourAnswerWrong,

  /// Review: the key, not picked.
  correctAnswer,

  /// Review: picked and right.
  yourAnswerCorrect,

  /// Review: neither picked nor the key.
  reviewOther,
}

/// One MCQ choice (Components.dc.html §2). Whole tile is the target;
/// cross-out is a separate 48 px target.
class ChoiceTile extends StatefulWidget {
  const ChoiceTile({
    required this.letter,
    required this.content,
    required this.state,
    super.key,
    this.onSelect,
    this.onEliminate,
    this.onRestore,
  });

  final String letter;

  /// `MathText` markup.
  final String content;
  final ChoiceTileState state;
  final VoidCallback? onSelect;
  final VoidCallback? onEliminate;
  final VoidCallback? onRestore;

  @override
  State<ChoiceTile> createState() => _ChoiceTileState();
}

class _ChoiceTileState extends State<ChoiceTile> {
  bool _hovered = false;
  bool _focused = false;

  bool get _interactive =>
      widget.onSelect != null &&
      (widget.state == ChoiceTileState.idle ||
          widget.state == ChoiceTileState.selected);

  bool get _chosen => switch (widget.state) {
    ChoiceTileState.selected ||
    ChoiceTileState.correct ||
    ChoiceTileState.incorrect ||
    ChoiceTileState.yourAnswerWrong ||
    ChoiceTileState.yourAnswerCorrect => true,
    ChoiceTileState.idle ||
    ChoiceTileState.eliminated ||
    ChoiceTileState.disabled ||
    ChoiceTileState.correctAnswer ||
    ChoiceTileState.reviewOther => false,
  };

  @override
  Widget build(BuildContext context) {
    final look = _ChoiceLook.of(
      context,
      widget.state,
      hovered: _hovered && _interactive,
    );
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    const radius = BorderRadius.all(Radius.circular(BookletRadius.sm));
    final eliminated = widget.state == ChoiceTileState.eliminated;
    final trailing = _trailing(look);
    final trailingIsButton = trailing != null && look.status == null;

    final body = StrikeThrough(
      struck: eliminated,
      color: scheme.onSurfaceVariant,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: BookletSpace.s3,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              top: (BookletSize.touchTarget - BookletSize.choiceBadge) / 2,
            ),
            child: _Badge(letter: widget.letter, look: look),
          ),
          Expanded(
            child: Opacity(
              opacity: eliminated ? BookletOpacity.eliminated : 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: BookletSpace.s3),
                child: MathText(
                  widget.content,
                  style: textTheme.bodyMedium?.copyWith(color: look.text),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Widget tile = Container(
      constraints: const BoxConstraints(minHeight: BookletSize.largeControl),
      padding: EdgeInsetsDirectional.only(
        start: BookletSpace.s3 + BookletStroke.thin,
        top: BookletSpace.s1 + BookletStroke.thin,
        bottom: BookletSpace.s1 + BookletStroke.thin,
        end: trailingIsButton
            ? BookletStroke.thin
            : BookletSpace.s3 + BookletStroke.thin,
      ),
      decoration: BoxDecoration(color: look.background, borderRadius: radius),
      foregroundDecoration: look.dashed
          ? null
          : BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: look.border, width: look.borderWidth),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: BookletSpace.s3,
        children: [Expanded(child: body), ?trailing],
      ),
    );
    if (look.dashed) {
      tile = CustomPaint(
        foregroundPainter: DashedBorderPainter(
          color: look.border,
          radius: BookletRadius.sm,
        ),
        child: tile,
      );
    }

    return Semantics(
      container: true,
      inMutuallyExclusiveGroup: true,
      checked: _chosen,
      enabled: _interactive,
      label: 'Choice ${widget.letter}',
      child: FocusableActionDetector(
        enabled: _interactive,
        mouseCursor: _interactive
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onSelect?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _interactive ? widget.onSelect : null,
          child: FocusRing(
            visible: _focused && _interactive,
            borderRadius: BookletRadius.sm,
            child: tile,
          ),
        ),
      ),
    );
  }

  Widget? _trailing(_ChoiceLook look) {
    final status = look.status;
    if (status != null) {
      return SizedBox(
        height: BookletSize.touchTarget,
        child: Align(
          widthFactor: 1,
          child: FeedbackLabel(
            icon: status.icon,
            label: status.label,
            color: status.color,
          ),
        ),
      );
    }
    if (widget.state == ChoiceTileState.eliminated &&
        widget.onRestore != null) {
      return TextButton.icon(
        onPressed: widget.onRestore,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: BookletSpace.s3),
        ),
        icon: const Icon(Icons.undo_rounded, size: BookletSize.iconSmall),
        label: Text(
          'Undo',
          semanticsLabel: 'Restore choice ${widget.letter}',
        ),
      );
    }
    if (_interactive && widget.onEliminate != null) {
      return IconButton(
        onPressed: widget.onEliminate,
        tooltip: 'Cross out choice ${widget.letter}',
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        icon: const Icon(
          Icons.strikethrough_s_rounded,
          size: BookletSize.iconSmall,
        ),
      );
    }
    return null;
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.letter, required this.look});

  final String letter;
  final _ChoiceLook look;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minWidth: BookletSize.choiceBadge,
        minHeight: BookletSize.choiceBadge,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: look.badgeFill,
        border: Border.all(
          color: look.badgeBorder,
          width: look.badgeBorderWidth,
        ),
        borderRadius: const BorderRadius.all(
          Radius.circular(BookletRadius.xs),
        ),
      ),
      child: Text(
        letter,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: look.badgeText,
          fontWeight: look.badgeWeight,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

typedef _Status = ({IconData icon, String label, Color color});

final class _ChoiceLook {
  const _ChoiceLook({
    required this.background,
    required this.border,
    required this.borderWidth,
    required this.badgeBorder,
    required this.badgeBorderWidth,
    required this.badgeText,
    required this.text,
    this.badgeFill,
    this.badgeWeight = FontWeight.w600,
    this.dashed = false,
    this.status,
  });

  /// 1 px rule, outlined badge.
  factory _ChoiceLook.plain({
    required Color background,
    required Color border,
    required Color badgeBorder,
    required Color text,
    bool dashed = false,
  }) => _ChoiceLook(
    background: background,
    border: border,
    borderWidth: BookletStroke.thin,
    badgeBorder: badgeBorder,
    badgeBorderWidth: BookletStroke.badge,
    badgeText: text,
    text: text,
    dashed: dashed,
  );

  /// 2 px accent edge, solid accent badge.
  factory _ChoiceLook.filled({
    required Color accent,
    required Color container,
    required Color onAccent,
    required Color text,
    _Status? status,
  }) => _ChoiceLook(
    background: container,
    border: accent,
    borderWidth: BookletStroke.strong,
    badgeFill: accent,
    badgeBorder: accent,
    badgeBorderWidth: BookletStroke.badge,
    badgeText: onAccent,
    text: text,
    status: status,
  );

  factory _ChoiceLook.of(
    BuildContext context,
    ChoiceTileState state, {
    required bool hovered,
  }) {
    final s = Theme.of(context).colorScheme;
    final b = context.booklet;
    return switch (state) {
      ChoiceTileState.idle => _ChoiceLook.plain(
        background: hovered ? s.surfaceContainer : s.surface,
        border: hovered ? b.inkDisabled : s.outlineVariant,
        badgeBorder: s.outline,
        text: s.onSurface,
      ),
      ChoiceTileState.selected => _ChoiceLook.filled(
        accent: s.primary,
        container: s.primaryContainer,
        onAccent: s.onPrimary,
        text: s.onSurface,
      ),
      ChoiceTileState.eliminated => _ChoiceLook.plain(
        background: s.surface,
        border: s.outlineVariant,
        badgeBorder: b.inkDisabled,
        text: b.inkDisabled,
        dashed: true,
      ),
      ChoiceTileState.disabled => _ChoiceLook.plain(
        background: s.surface,
        border: s.outlineVariant,
        badgeBorder: b.inkDisabled,
        text: b.inkDisabled,
      ),
      ChoiceTileState.reviewOther => _ChoiceLook.plain(
        background: s.surface,
        border: s.outlineVariant,
        badgeBorder: b.inkDisabled,
        text: s.onSurfaceVariant,
      ),
      ChoiceTileState.correct => _ChoiceLook.filled(
        accent: b.greenTick,
        container: b.greenTickContainer,
        onAccent: s.surface,
        text: s.onSurface,
        status: (
          icon: Icons.check_circle_rounded,
          label: 'Correct',
          color: b.greenTick,
        ),
      ),
      ChoiceTileState.yourAnswerCorrect => _ChoiceLook.filled(
        accent: b.greenTick,
        container: b.greenTickContainer,
        onAccent: s.surface,
        text: s.onSurface,
        status: (
          icon: Icons.check_circle_rounded,
          label: 'Your answer · Correct',
          color: b.greenTick,
        ),
      ),
      ChoiceTileState.incorrect => _ChoiceLook.filled(
        accent: s.error,
        container: s.errorContainer,
        onAccent: s.surface,
        text: s.onSurface,
        status: (
          icon: Icons.cancel_rounded,
          label: 'Incorrect',
          color: s.error,
        ),
      ),
      ChoiceTileState.yourAnswerWrong => _ChoiceLook.filled(
        accent: s.error,
        container: s.errorContainer,
        onAccent: s.surface,
        text: s.onSurface,
        status: (
          icon: Icons.cancel_rounded,
          label: 'Your answer',
          color: s.error,
        ),
      ),
      ChoiceTileState.correctAnswer => _ChoiceLook(
        background: s.surface,
        border: b.greenTick,
        borderWidth: BookletStroke.strong,
        badgeBorder: b.greenTick,
        badgeBorderWidth: BookletStroke.strong,
        badgeText: b.greenTick,
        badgeWeight: FontWeight.w700,
        text: s.onSurface,
        status: (
          icon: Icons.check_circle_outline_rounded,
          label: 'Correct answer',
          color: b.greenTick,
        ),
      ),
    };
  }

  final Color background;
  final Color border;
  final double borderWidth;
  final Color? badgeFill;
  final Color badgeBorder;
  final double badgeBorderWidth;
  final Color badgeText;
  final FontWeight badgeWeight;
  final Color text;
  final bool dashed;
  final _Status? status;
}
```

Note: `?trailing` is the Dart 3.8 null-aware collection element; if the analyzer rejects it, use `if (trailing != null) trailing`.

- [ ] **Step 5: Run to verify they pass** — test PASS. If the keyboard test fails because `Tab` lands on the cross-out button first, keep the tile's `FocusableActionDetector` outermost (as written) and check focus order with `debugDumpFocusTree()`; fix order, not the test. Then format, analyze, full `flutter test`.
- [ ] **Step 6: Visual check** — temporarily render all ten states in `lib/core/router/placeholder_screen.dart`, `flutter run -d chrome --dart-define-from-file=env/dev.json` at 360 and 1280; compare with `Components.dc.html` §2 (open the HTML in Chrome). Check hover (mouse) and focus (Tab). Revert the screen before committing.
- [ ] **Step 7: Commit**: `feat(F-4): ChoiceTile with practice and review states`

---

## Task 4: `SprInput`

**Files:**
- Create: `apps/client/lib/shared/widgets/spr_input.dart`
- Test: `apps/client/test/shared/widgets/spr_input_test.dart`

**Interfaces:**
- Consumes: `parseSprAnswer`, `SprInvalid`, `SprInvalidReason`, `sprMaxLength`, `sprMaxLengthNegative` (`spr_answer.dart`); `SprKeyHint`, `normalizeSprDigits`, `sprPreviewTex`, `sprInputMaxChars` (Task 1); `FeedbackLabel` (Task 3); `MathText`.
- Produces:
  - `enum SprInputState { editable, disabled, correct, incorrect }`
  - `SprInput({required String value, required ValueChanged<String> onChanged, SprInputState state = SprInputState.editable, SprKeyHint? keyHint, String? correctAnswer, bool useKeypad = false, FocusNode? focusNode, VoidCallback? onSubmitted})` — controlled: parent owns the text. `useKeypad` → `TextInputType.none` (system keyboard stays down, cursor shows). `keyHint` (from `applySprKey`) wins over parse hints. `correctAnswer` is display text from `get_attempt_review`, shown only in `incorrect`.
  - `String? sprHintText(String value, {SprKeyHint? keyHint})` — `MathText` markup or null.
  - `final List<TextInputFormatter> sprInputFormatters`.

Behaviour (`Components.dc.html:145-181`): label "Your answer"; field 200×56, value 20/500 tabular; Answer Preview beside the field when the text parses; info hint (never red) for mixed number / too long / zero denominator / keypad refusals; neutral helper otherwise ("Fraction, decimal or integer" when empty, "Answer preview appears when it's a number" while incomplete). Review states replace the field with a read-only box + `FeedbackLabel`.

- [ ] **Step 1: Write the failing tests** (via `test-writer`)

```dart
// test/shared/widgets/spr_input_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/grading/spr_editing.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/shared/widgets/spr_input.dart';

Future<List<String>> pumpSpr(
  WidgetTester tester, {
  String value = '',
  SprInputState state = SprInputState.editable,
  SprKeyHint? keyHint,
  String? correctAnswer,
  bool useKeypad = false,
}) async {
  final changes = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SprInput(
          value: value,
          onChanged: changes.add,
          state: state,
          keyHint: keyHint,
          correctAnswer: correctAnswer,
          useKeypad: useKeypad,
        ),
      ),
    ),
  );
  return changes;
}

void main() {
  testWidgets('F-4: empty field shows placeholder and format helper', (t) async {
    await pumpSpr(t);
    expect(find.text('Your answer'), findsOneWidget);
    expect(find.text('Type answer'), findsOneWidget);
    expect(find.text('Fraction, decimal or integer'), findsOneWidget);
  });

  testWidgets('F-4: typing reports the text', (t) async {
    final changes = await pumpSpr(t);
    await t.enterText(find.byType(TextField), '-3/4');
    expect(changes.last, '-3/4');
  });

  testWidgets('F-4: a valid value shows the Answer preview', (t) async {
    await pumpSpr(t, value: '-3/4');
    expect(find.text('Answer preview'), findsOneWidget);
    expect(find.byType(Math), findsOneWidget);
  });

  testWidgets('F-4: incomplete value shows the preview helper, no preview', (t) async {
    await pumpSpr(t, value: '3/');
    expect(find.text("Answer preview appears when it's a number"), findsOneWidget);
    expect(find.text('Answer preview'), findsNothing);
  });

  for (final (value, phrase) in [
    ('1 1/2', "Mixed numbers aren't accepted"),
    ('0.66667', 'Up to 5 characters'),
    ('3/0', "can't have 0"),
  ]) {
    testWidgets('F-4: "$value" shows an info hint', (t) async {
      await pumpSpr(t, value: value);
      expect(find.textContaining(phrase), findsOneWidget);
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    });
  }

  testWidgets('F-4: the field accepts a space and 7 characters (hints reachable)', (t) async {
    final changes = await pumpSpr(t);
    await t.enterText(find.byType(TextField), '1 1/2');
    expect(changes.last, '1 1/2');
    await t.enterText(find.byType(TextField), '0.66667');
    expect(changes.last, '0.66667');
  });

  testWidgets('F-4: keypad hint wins over parse hints', (t) async {
    await pumpSpr(t, value: '3/4', keyHint: SprKeyHint.secondSlash);
    expect(find.textContaining('only one'), findsOneWidget);
  });

  testWidgets('F-4: Arabic-Indic digits are normalised to ASCII', (t) async {
    final changes = await pumpSpr(t);
    await t.enterText(find.byType(TextField), '٣/٤');
    expect(changes.last, '3/4');
  });

  testWidgets('F-4: letters are filtered out', (t) async {
    final changes = await pumpSpr(t);
    await t.enterText(find.byType(TextField), '12abc');
    expect(changes.last, '12');
  });

  testWidgets('F-4: parent value updates the field', (t) async {
    await pumpSpr(t, value: '1');
    await pumpSpr(t, value: '12');
    final field = t.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, '12');
    expect(field.controller!.selection.baseOffset, 2);
  });

  testWidgets('F-4: disabled field is not editable', (t) async {
    await pumpSpr(t, value: '12', state: SprInputState.disabled);
    expect(t.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(find.text('Fraction, decimal or integer'), findsNothing);
  });

  testWidgets('F-4: keypad mode keeps the system keyboard down', (t) async {
    await pumpSpr(t, useKeypad: true);
    expect(t.widget<TextField>(find.byType(TextField)).keyboardType, TextInputType.none);
  });

  testWidgets('F-4: review correct shows the value and Correct', (t) async {
    await pumpSpr(t, value: '12', state: SprInputState.correct);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Correct'), findsOneWidget);
  });

  testWidgets('F-4: review incorrect shows the correct answer', (t) async {
    await pumpSpr(t, value: '15', state: SprInputState.incorrect, correctAnswer: '3');
    expect(find.text('Incorrect'), findsOneWidget);
    expect(find.textContaining('Correct answer: 3'), findsOneWidget);
  });

  test('F-4: sprHintText maps each refusal to copy', () {
    expect(sprHintText('3/4', keyHint: SprKeyHint.secondDot), contains('decimal point'));
    expect(sprHintText('1.5', keyHint: SprKeyHint.slashAndDot), contains('not both'));
    expect(sprHintText('12'), isNull);
    expect(sprHintText('3/'), isNull);
  });
}
```

- [ ] **Step 2: Run to verify they fail** — `flutter test test/shared/widgets/spr_input_test.dart` → FAIL.

- [ ] **Step 3: Implement `spr_input.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sat_east_client/core/grading/spr_answer.dart';
import 'package:sat_east_client/core/grading/spr_editing.dart';
import 'package:sat_east_client/core/math_render/math_text.dart';
import 'package:sat_east_client/core/theme/booklet_colors.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/shared/widgets/feedback_label.dart';

enum SprInputState { editable, disabled, correct, incorrect }

/// Hint copy (MathText markup) for [value], or null. Hints are info, never
/// red (Components.dc.html §3).
String? sprHintText(String value, {SprKeyHint? keyHint}) {
  if (keyHint != null) {
    return switch (keyHint) {
      SprKeyHint.secondSlash => 'A fraction has only one slash.',
      SprKeyHint.secondDot => 'A number has only one decimal point.',
      SprKeyHint.slashAndDot => 'Use a fraction or a decimal, not both.',
    };
  }
  return switch (parseSprAnswer(value)) {
    SprInvalid(reason: SprInvalidReason.mixedNumber) =>
      "Mixed numbers aren't accepted. Enter **3/2** or **1.5**.",
    SprInvalid(reason: SprInvalidReason.tooLong) =>
      'Up to $sprMaxLength characters ($sprMaxLengthNegative with a minus '
          'sign). Try **.6666** or **2/3**.',
    SprInvalid(reason: SprInvalidReason.zeroDenominator) =>
      "A fraction can't have 0 on the bottom.",
    SprInvalid() || SprValid() => null,
  };
}

/// Normalises digits, then keeps only SPR characters. Spaces stay so the
/// mixed-number hint can show; the cap is above the grading limit so the
/// length hint can show.
final List<TextInputFormatter> sprInputFormatters = [
  TextInputFormatter.withFunction(
    (oldValue, newValue) =>
        newValue.copyWith(text: normalizeSprDigits(newValue.text)),
  ),
  FilteringTextInputFormatter.allow(RegExp(r'[0-9./\- ]')),
  LengthLimitingTextInputFormatter(sprInputMaxChars),
];

/// Student-produced response field with live Answer Preview (§3). Controlled:
/// the parent owns [value].
class SprInput extends StatefulWidget {
  const SprInput({
    required this.value,
    required this.onChanged,
    super.key,
    this.state = SprInputState.editable,
    this.keyHint,
    this.correctAnswer,
    this.useKeypad = false,
    this.focusNode,
    this.onSubmitted,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final SprInputState state;

  /// Why the last keypad key was ignored; wins over parse hints.
  final SprKeyHint? keyHint;

  /// Server-provided key text, shown only in [SprInputState.incorrect].
  final String? correctAnswer;

  /// Phone + custom keypad: system keyboard stays down.
  final bool useKeypad;
  final FocusNode? focusNode;
  final VoidCallback? onSubmitted;

  @override
  State<SprInput> createState() => _SprInputState();
}

class _SprInputState extends State<SprInput> {
  late final TextEditingController _controller;
  FocusNode? _ownFocus;

  FocusNode get _focus => widget.focusNode ?? _ownFocus!;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    if (widget.focusNode == null) _ownFocus = FocusNode();
  }

  @override
  void didUpdateWidget(SprInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _ownFocus?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final review =
        widget.state == SprInputState.correct ||
        widget.state == SprInputState.incorrect;
    final disabled = widget.state == SprInputState.disabled;
    final quiet = review || disabled;
    final preview = quiet ? null : sprPreviewTex(widget.value);
    final hint = quiet
        ? null
        : sprHintText(widget.value, keyHint: widget.keyHint);
    final helper = quiet || hint != null || preview != null
        ? null
        : widget.value.isEmpty
        ? 'Fraction, decimal or integer'
        : "Answer preview appears when it's a number";
    final valueStyle = text.titleLarge?.copyWith(
      fontWeight: FontWeight.w500,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final correctAnswer = widget.correctAnswer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: BookletSpace.s2,
      children: [
        Text(
          'Your answer',
          style: text.labelLarge?.copyWith(
            color: disabled ? context.booklet.inkDisabled : scheme.onSurface,
          ),
        ),
        Wrap(
          spacing: BookletSpace.s4,
          runSpacing: BookletSpace.s2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: BookletSize.sprInputWidth,
              height: BookletSize.largeControl,
              child: review
                  ? _ReviewBox(
                      value: widget.value,
                      correct: widget.state == SprInputState.correct,
                      style: valueStyle,
                    )
                  : _field(context, valueStyle, hinted: hint != null),
            ),
            if (preview != null) _Preview(tex: preview),
          ],
        ),
        if (hint != null) _Hint(text: hint),
        if (helper != null)
          Text(
            helper,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        if (widget.state == SprInputState.incorrect && correctAnswer != null)
          _CorrectAnswer(value: correctAnswer),
      ],
    );
  }

  Widget _field(
    BuildContext context,
    TextStyle? valueStyle, {
    required bool hinted,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final booklet = context.booklet;
    final disabled = widget.state == SprInputState.disabled;
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(BookletRadius.sm)),
      borderSide: BorderSide(color: color, width: width),
    );
    final onSubmitted = widget.onSubmitted;

    return Semantics(
      label: 'Your answer',
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        enabled: !disabled,
        expands: true,
        maxLines: null,
        textAlignVertical: TextAlignVertical.center,
        keyboardType: widget.useKeypad
            ? TextInputType.none
            : TextInputType.text,
        autocorrect: false,
        enableSuggestions: false,
        inputFormatters: sprInputFormatters,
        style: valueStyle?.copyWith(
          color: disabled ? booklet.inkDisabled : scheme.onSurface,
        ),
        onChanged: widget.onChanged,
        onSubmitted: onSubmitted == null ? null : (_) => onSubmitted(),
        decoration: InputDecoration(
          hintText: 'Type answer',
          hintStyle: valueStyle?.copyWith(
            fontWeight: FontWeight.w400,
            color: booklet.inkDisabled,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: BookletSpace.s4,
          ),
          filled: disabled,
          fillColor: scheme.surfaceContainer,
          enabledBorder: hinted ? border(booklet.info, BookletStroke.thin) : null,
          focusedBorder: hinted
              ? border(booklet.info, BookletStroke.strong)
              : null,
          disabledBorder: border(scheme.outlineVariant, BookletStroke.thin),
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.tex});

  final String tex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsetsDirectional.only(start: BookletSpace.s4),
      decoration: BoxDecoration(
        border: BorderDirectional(
          start: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Answer preview',
            style: text.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          MathText(
            '\\($tex\\)',
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: BookletSpace.s1,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: BookletSize.iconStatus,
            color: context.booklet.info,
          ),
          Flexible(
            child: MathText(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewBox extends StatelessWidget {
  const _ReviewBox({
    required this.value,
    required this.correct,
    required this.style,
  });

  final String value;
  final bool correct;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final booklet = context.booklet;
    final accent = correct ? booklet.greenTick : scheme.error;
    const radius = BorderRadius.all(Radius.circular(BookletRadius.sm));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: BookletSpace.s4),
      decoration: BoxDecoration(
        color: correct ? booklet.greenTickContainer : scheme.errorContainer,
        borderRadius: radius,
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: accent, width: BookletStroke.strong),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value,
              style: style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          FeedbackLabel(
            icon: correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
            label: correct ? 'Correct' : 'Incorrect',
            color: accent,
          ),
        ],
      ),
    );
  }
}

class _CorrectAnswer extends StatelessWidget {
  const _CorrectAnswer({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w400);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: BookletSpace.s1,
      children: [
        Icon(
          Icons.check_circle_outline_rounded,
          size: BookletSize.iconStatus,
          color: context.booklet.greenTick,
        ),
        Text.rich(
          TextSpan(
            text: 'Correct answer: ',
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          style: style,
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run to verify they pass** — test PASS; format; analyze; full `flutter test`. If `find.textContaining(...)` misses hint copy because `MathText` splits bold runs into spans, match a phrase inside one plain run (the phrases above are chosen that way).
- [ ] **Step 5: Visual check** — same temporary-screen routine as Task 3 for all `Components.dc.html` §3 states; revert.
- [ ] **Step 6: Commit**: `feat(F-4): SprInput with answer preview and info hints`

---

## Task 5: `SprKeypad`

**Files:**
- Create: `apps/client/lib/shared/widgets/spr_keypad.dart`
- Test: `apps/client/test/shared/widgets/spr_keypad_test.dart`

**Interfaces:**
- Consumes: `SprKey` (Task 1); tokens.
- Produces: `SprKeypad({required ValueChanged<SprKey> onKey, required VoidCallback onHide})`. Stateless about text: the parent (QuestionView, later) runs `applySprKey(value, key)` and feeds `SprInput.value` / `keyHint`. Phone only (decided in QuestionView by layout).

Layout (`Components.dc.html:187-205`): 4 columns, gap 8, keys 56 tall; rows `1 2 3 ⌫` / `4 5 6 /` / `7 8 9 −` / `. 0(×2) hide`. Digits on `surface`, operators/actions on `surfaceContainer`, 1 px `outlineVariant`, radius sm. Pressed: `primaryContainer` fill + `primary` edge + `primary` text. Panel: `surfaceContainer`, top rule `outlineVariant`, padding 8/8/16, bottom safe area. Always LTR.

- [ ] **Step 1: Write the failing tests** (via `test-writer`)

```dart
// test/shared/widgets/spr_keypad_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/grading/spr_editing.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/shared/widgets/spr_keypad.dart';

Future<(List<SprKey>, List<void>)> pumpKeypad(
  WidgetTester tester, {
  double width = 360,
  double textScale = 1,
  TextDirection direction = TextDirection.ltr,
}) async {
  final keys = <SprKey>[];
  final hides = <void>[];
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: Directionality(
          textDirection: direction,
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: SprKeypad(onKey: keys.add, onHide: () => hides.add(null)),
            ),
          ),
        ),
      ),
    ),
  );
  return (keys, hides);
}

void main() {
  testWidgets('F-4: digit keys emit their key', (t) async {
    final (keys, _) = await pumpKeypad(t);
    await t.tap(find.text('7'));
    await t.tap(find.text('0'));
    expect(keys, [SprKey.seven, SprKey.zero]);
  });

  testWidgets('F-4: minus key shows U+2212 and emits SprKey.minus', (t) async {
    final (keys, _) = await pumpKeypad(t);
    await t.tap(find.text('−'));
    expect(keys, [SprKey.minus]);
  });

  testWidgets('F-4: slash, dot and delete emit their keys', (t) async {
    final (keys, _) = await pumpKeypad(t);
    await t.tap(find.text('/'));
    await t.tap(find.text('.'));
    await t.tap(find.bySemanticsLabel('Delete'));
    expect(keys, [SprKey.slash, SprKey.dot, SprKey.backspace]);
  });

  testWidgets('F-4: hide key calls onHide', (t) async {
    final (_, hides) = await pumpKeypad(t);
    await t.tap(find.bySemanticsLabel('Hide keypad'));
    expect(hides, hasLength(1));
  });

  testWidgets('F-4: pressed key uses the primary container', (t) async {
    await pumpKeypad(t);
    final gesture = await t.startGesture(t.getCenter(find.text('8')));
    await t.pump();
    final box = t.widget<Container>(
      find.ancestor(of: find.text('8'), matching: find.byType(Container)).first,
    );
    expect(
      (box.decoration! as BoxDecoration).color,
      AppTheme.light().colorScheme.primaryContainer,
    );
    await gesture.up();
  });

  testWidgets('F-4: keys are 56 px tall', (t) async {
    await pumpKeypad(t);
    final box = find.ancestor(of: find.text('5'), matching: find.byType(Container)).first;
    expect(t.getSize(box).height, 56);
  });

  testWidgets('F-4: keypad keeps LTR order under RTL', (t) async {
    await pumpKeypad(t, direction: TextDirection.rtl);
    expect(t.getCenter(find.text('1')).dx, lessThan(t.getCenter(find.text('3')).dx));
  });

  testWidgets('F-4: 360 px at 2x text does not overflow', (t) async {
    await pumpKeypad(t, textScale: 2);
    expect(t.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run to verify they fail** — `flutter test test/shared/widgets/spr_keypad_test.dart` → FAIL.

- [ ] **Step 3: Implement `spr_keypad.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:sat_east_client/core/grading/spr_editing.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';

/// Docked SPR keypad for phones (Components.dc.html §3.1). Emits keys only;
/// the parent applies them with `applySprKey`.
class SprKeypad extends StatelessWidget {
  const SprKeypad({required this.onKey, required this.onHide, super.key});

  final ValueChanged<SprKey> onKey;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget digit(int n) => _KeypadKey(
      label: '$n',
      semanticsLabel: '$n',
      onTap: () => onKey(SprKey.digit(n)),
    );

    Widget row(List<(Widget, int)> keys) => Row(
      spacing: BookletSpace.s2,
      children: [
        for (final (key, flex) in keys) Expanded(flex: flex, child: key),
      ],
    );

    return Directionality(
      textDirection: TextDirection.ltr,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              BookletSpace.s2,
              BookletSpace.s2,
              BookletSpace.s2,
              BookletSpace.s4,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: BookletSpace.s2,
              children: [
                row([
                  (digit(1), 1),
                  (digit(2), 1),
                  (digit(3), 1),
                  (
                    _KeypadKey(
                      icon: Icons.backspace_outlined,
                      semanticsLabel: 'Delete',
                      operator: true,
                      onTap: () => onKey(SprKey.backspace),
                    ),
                    1,
                  ),
                ]),
                row([
                  (digit(4), 1),
                  (digit(5), 1),
                  (digit(6), 1),
                  (
                    _KeypadKey(
                      label: '/',
                      semanticsLabel: 'Fraction bar',
                      operator: true,
                      onTap: () => onKey(SprKey.slash),
                    ),
                    1,
                  ),
                ]),
                row([
                  (digit(7), 1),
                  (digit(8), 1),
                  (digit(9), 1),
                  (
                    _KeypadKey(
                      label: '−',
                      semanticsLabel: 'Minus sign',
                      operator: true,
                      onTap: () => onKey(SprKey.minus),
                    ),
                    1,
                  ),
                ]),
                row([
                  (
                    _KeypadKey(
                      label: '.',
                      semanticsLabel: 'Decimal point',
                      operator: true,
                      onTap: () => onKey(SprKey.dot),
                    ),
                    1,
                  ),
                  (digit(0), 2),
                  (
                    _KeypadKey(
                      icon: Icons.keyboard_hide_outlined,
                      semanticsLabel: 'Hide keypad',
                      operator: true,
                      onTap: onHide,
                    ),
                    1,
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KeypadKey extends StatefulWidget {
  const _KeypadKey({
    required this.semanticsLabel,
    required this.onTap,
    this.label,
    this.icon,
    this.operator = false,
  });

  final String semanticsLabel;
  final VoidCallback onTap;
  final String? label;
  final IconData? icon;
  final bool operator;

  @override
  State<_KeypadKey> createState() => _KeypadKeyState();
}

class _KeypadKeyState extends State<_KeypadKey> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = _pressed ? scheme.primary : scheme.onSurface;
    final icon = widget.icon;
    final background = _pressed
        ? scheme.primaryContainer
        : widget.operator
        ? scheme.surfaceContainer
        : scheme.surface;

    return Semantics(
      button: true,
      label: widget.semanticsLabel,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: Container(
          height: BookletSize.largeControl,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            border: Border.all(
              color: _pressed ? scheme.primary : scheme.outlineVariant,
            ),
            borderRadius: const BorderRadius.all(
              Radius.circular(BookletRadius.sm),
            ),
          ),
          child: icon != null
              ? Icon(icon, color: foreground)
              : Text(
                  widget.label!,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: foreground,
                  ),
                ),
        ),
      ),
    );
  }
}
```

Note: the keys are fixed at 56 px; at 2.0 text scale the 40 px glyph still fits. If the overflow test fails, wrap the label in `FittedBox(fit: BoxFit.scaleDown)` — do not grow the key.

- [ ] **Step 4: Run to verify they pass** — test PASS; format; analyze; full `flutter test`.
- [ ] **Step 5: Commit**: `feat(F-4): SprKeypad for phones`

---

## Task 6: Golden setup + component goldens + CI exclude

**Files:**
- Create: `apps/client/dart_test.yaml`
- Create: `apps/client/test/goldens/flutter_test_config.dart`
- Create: `apps/client/test/goldens/golden_harness.dart`
- Create: `apps/client/test/goldens/components/choice_tile_golden_test.dart`
- Create: `apps/client/test/goldens/components/spr_golden_test.dart`
- Create (generated): `apps/client/test/goldens/components/goldens/*.png`
- Modify: `.github/workflows/ci.yml:31` (`flutter test` → `flutter test --exclude-tags golden`)

**Interfaces:**
- Consumes: Tasks 3–5 widgets, `AppTheme`, tokens.
- Produces: `expectGolden(WidgetTester, {required String name, required Widget child, required double width, Brightness brightness, double textScale})`, `const goldenWidths = [360.0, 1280.0]` — reused by PR B and the QuestionView PR.

`flutter_test_config.dart` applies only to tests under `test/goldens/`, so existing tests keep the Ahem font and are unaffected.

- [ ] **Step 1: Declare the tag** — `apps/client/dart_test.yaml`:

```yaml
tags:
  golden:
    description: Pixel goldens. Baselines generated on Windows; excluded on CI.
```

- [ ] **Step 2: Load real fonts for goldens** — `test/goldens/flutter_test_config.dart`:

```dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads every font in FontManifest.json (Noto, MaterialIcons, KaTeX from
/// flutter_math_fork) so goldens show real glyphs instead of Ahem boxes.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final manifest =
      json.decode(await rootBundle.loadString('FontManifest.json'))
          as List<dynamic>;
  for (final family in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(family['family'] as String);
    for (final font
        in (family['fonts'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
  await testMain();
}
```

- [ ] **Step 3: Golden harness** — `test/goldens/golden_harness.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';

const goldenWidths = [360.0, 1280.0];

const _boundary = ValueKey('golden-boundary');

/// Pumps [child] in the booklet theme at [width] and compares it with
/// `goldens/<name>.png` next to the calling test. Wide layouts are capped at
/// the question column, as in QuestionView.
Future<void> expectGolden(
  WidgetTester tester, {
  required String name,
  required Widget child,
  required double width,
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final theme = brightness == Brightness.light
      ? AppTheme.light()
      : AppTheme.dark();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: Scaffold(
          body: SingleChildScrollView(
            child: RepaintBoundary(
              key: _boundary,
              child: ColoredBox(
                color: theme.colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(BookletSpace.s4),
                  child: Align(
                    alignment: AlignmentDirectional.topStart,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: BookletSize.questionColumn,
                      ),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await expectLater(
    find.byKey(_boundary),
    matchesGoldenFile('goldens/$name.png'),
  );
}
```

- [ ] **Step 4: Golden tests** (via `test-writer`)

`test/goldens/components/choice_tile_golden_test.dart`:

```dart
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/shared/widgets/choice_tile.dart';

import '../golden_harness.dart';

const _rows = <(ChoiceTileState, String)>[
  (ChoiceTileState.idle, r'\(x = -3\)'),
  (ChoiceTileState.selected, r'\(\frac{3}{4}\)'),
  (ChoiceTileState.eliminated, r'\(x = 9\)'),
  (ChoiceTileState.disabled, r'\(x = -3\)'),
  (
    ChoiceTileState.idle,
    r'The line rises 3 units for each unit to the right, so its slope is \(3\).',
  ),
  (ChoiceTileState.idle, r'ميل المستقيم يساوي \(3\).'),
  (ChoiceTileState.correct, r'\(\frac{3}{4}\)'),
  (ChoiceTileState.incorrect, r'\(x = -3\)'),
  (ChoiceTileState.yourAnswerWrong, r'\(x = 15\)'),
  (ChoiceTileState.correctAnswer, r'\(x = 3\)'),
  (ChoiceTileState.yourAnswerCorrect, r'\(x = 3\)'),
  (ChoiceTileState.reviewOther, r'\(x = \frac{3}{5}\)'),
];

Widget _sheet() => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  spacing: BookletSpace.s3,
  children: [
    for (final (i, (state, content)) in _rows.indexed)
      ChoiceTile(
        letter: 'ABCD'[i % 4],
        content: content,
        state: state,
        onSelect: () {},
        onEliminate: () {},
        onRestore: () {},
      ),
  ],
);

void main() {
  for (final width in goldenWidths) {
    for (final brightness in Brightness.values) {
      final name = 'choice_tile_${brightness.name}_${width.toInt()}';
      testWidgets('F-4: golden $name', (t) async {
        await expectGolden(
          t,
          name: name,
          child: _sheet(),
          width: width,
          brightness: brightness,
        );
      });
    }
  }

  testWidgets('F-4: golden choice_tile_light_360_text2x', (t) async {
    await expectGolden(
      t,
      name: 'choice_tile_light_360_text2x',
      child: _sheet(),
      width: 360,
      textScale: 2,
    );
  });
}
```

`test/goldens/components/spr_golden_test.dart`:

```dart
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/grading/spr_editing.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/shared/widgets/spr_input.dart';
import 'package:sat_east_client/shared/widgets/spr_keypad.dart';

import '../golden_harness.dart';

const _inputs = <(String, SprInputState, SprKeyHint?)>[
  ('', SprInputState.editable, null),
  ('3/', SprInputState.editable, null),
  ('-3/4', SprInputState.editable, null),
  ('1 1/2', SprInputState.editable, null),
  ('0.66667', SprInputState.editable, null),
  ('3/4', SprInputState.editable, SprKeyHint.secondSlash),
  ('12', SprInputState.disabled, null),
  ('12', SprInputState.correct, null),
  ('15', SprInputState.incorrect, null),
];

Widget _inputSheet() => Wrap(
  spacing: BookletSpace.s6,
  runSpacing: BookletSpace.s6,
  children: [
    for (final (value, state, hint) in _inputs)
      SprInput(
        value: value,
        onChanged: (_) {},
        state: state,
        keyHint: hint,
        correctAnswer: state == SprInputState.incorrect ? '3' : null,
      ),
  ],
);

void main() {
  for (final width in goldenWidths) {
    for (final brightness in Brightness.values) {
      final name = 'spr_input_${brightness.name}_${width.toInt()}';
      testWidgets('F-4: golden $name', (t) async {
        await expectGolden(
          t,
          name: name,
          child: _inputSheet(),
          width: width,
          brightness: brightness,
        );
      });
    }
  }

  for (final brightness in Brightness.values) {
    final name = 'spr_keypad_${brightness.name}_360';
    testWidgets('F-4: golden $name', (t) async {
      await expectGolden(
        t,
        name: name,
        child: SprKeypad(onKey: (_) {}, onHide: () {}),
        width: 360,
        brightness: brightness,
      );
    });
  }
}
```

- [ ] **Step 5: Generate baselines** — `flutter test --update-goldens --tags golden`. Expected: 12 PNGs in `test/goldens/components/goldens/`. Open every PNG and compare with `Components.dc.html` / `Components Dark.dc.html` in Chrome: real Noto glyphs (not black boxes), icons (not tofu), KaTeX math, dashed eliminated border, strike line, Arabic choice RTL. Fix widgets, not goldens, on any mismatch, then regenerate.
- [ ] **Step 6: Verify** — `flutter test --tags golden` → PASS; `flutter test --exclude-tags golden` → PASS (the CI command); plain `flutter test` → PASS.
- [ ] **Step 7: CI** — `.github/workflows/ci.yml` line 31: `- run: flutter test` → `- run: flutter test --exclude-tags golden`.
- [ ] **Step 8: Commit**: `test(F-4): golden setup and answer-input goldens`

---

## Task 7: Review gate + PR

- [ ] **Step 1:** `/flutter-code-quality:review-gate`, then `/flutter-code-review`; fix findings. Offer the `code-reviewer` agent.
- [ ] **Step 2:** `graphify update .` from repo root.
- [ ] **Step 3:** `git-expert`: push `feat/F-4-components-inputs`, open PR to `main`, title `feat(F-4): answer input components`. Body: what ships (`ChoiceTile` 10 states, `SprInput` + preview + hints, `SprKeypad`, `spr_editing.dart`, painters, focus ring, golden harness), the scope split (PR B + moves to QuestionView), golden strategy + CI change, tests run (unit/widget/golden counts), screenshots of 2 golden PNGs. End with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- [ ] **Step 4:** `gh pr checks --watch` → green. User merges.
- [ ] **Step 5:** Update memory `phase0-progress.md`: PR A number/state; next = plan for "Components B — buttons and feedback".

## Verification (whole plan)
- Each task: its test file, then `dart format .` (no changes), `flutter analyze --fatal-infos` (clean), `flutter test` (all pass) from `apps/client/`.
- Goldens: `flutter test --tags golden` passes locally on Windows; CI runs `flutter test --exclude-tags golden` and stays green.
- Visual: Chrome at 360 and 1280, temporary placeholder render of every §2/§3 state compared with `Components.dc.html` (light) and `Components Dark.dc.html` (OS dark mode); hover and keyboard focus checked by hand.

## Execution
Recommended: **subagent-driven** — one `implementer` per task (tests via `test-writer`, git via `git-expert`); router reviews each diff + test run before the next. Tasks 1→2→3→4→5→6 are sequential (each consumes the previous interfaces).
