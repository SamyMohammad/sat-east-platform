# F-4 Components B — buttons and feedback Implementation Plan

> **For agentic workers:** Use the existing subagent execution approach: test-writer creates tests first, implementers own disjoint production files, and a code-reviewer reviews the final change. Steps use checkbox syntax for tracking.

**Goal:** Implement Components.dc.html §1 and §8 using the booklet theme.

**Architecture:** Small reusable widgets in `apps/client/lib/shared/widgets/` receive display values and callbacks. They do not fetch data, coordinate business operations, or own feature state. Native Material controls retain keyboard, focus, semantics and dismissal behavior. Existing theme and golden harness are reused.

**Tech Stack:** Flutter 3.44.1, Dart 3.12.1, flutter_test; no dependencies added.

**Spec:** `docs/superpowers/specs/2026-10-13-f4-design-system-questionview-design.md` §2; `docs/design/claude-design-export/Components.dc.html` §1/§8 and its dark variant.

## Completion — 2026-10-14

Components B is implemented and locally verified on the current branch.
The full suite passes 272 tests: 244 unit/widget tests and 28 Windows goldens
(13 existing answer-input images plus 15 new feedback images). All new PNGs
were visually reviewed. Formatting, fatal-infos analysis and whitespace checks
pass. The independent review has no remaining material findings.

The generic external review-gate script still misidentifies digits in four
`BookletSpace` references as numeric EdgeInsets literals; these are verified
false positives. Its actual analyzer findings have been fixed.

No dependencies were added. Changes remain uncommitted for user review.
Next implementation stage: AppShell from the parent design-system plan;
QuestionView and the gallery follow it. Browser/staging verification will
follow when those application surfaces exist.

## Global Constraints

- Continue on the user-selected `feat/F-4-components-inputs` branch; preserve Components A changes.
- User's `continue` authorizes the next previously described component stage. The design is already supplied; no redesign or new feature decisions are required.
- Shared UI lives in `lib/shared/widgets/` (CLAUDE.md A.2, ADR-007).
- All visual values use the theme or tokens; touch targets are at least 48 px.
- English UI, mixed-direction content, light/dark support, 360/1280 widths and 2× text.
- Widgets render caller-supplied values only. No grading, timer, connectivity, navigation or error-mapping logic.
- Loading disables duplicate activation; reduced motion stops decorative indicator animation.
- Destructive button uses ink fill. Confirmation belongs to the caller's dialog flow.
- Dialog/sheet helpers use Material routes, return results, and expose the builder's context for dismissal. No app route or placeholder changes.
- Existing golden tag and Windows font setup stay in use; freeze tickers in golden sheets.
- No commit, push, deployment or PR during this implementation stage.

## Review Focus

1. Loading/disabled buttons cannot activate from tap or keyboard; accessible labels remain meaningful.
2. Long text at 360/2× wraps without clipping banner actions, chip labels or retry controls.
3. Dialog/sheet content scrolls with constrained height and keyboard insets, with safe areas and accessible dismissal.
4. Progress treats null as indeterminate and clamps invalid finite/NaN/infinite values for rendering only; semantics do not claim fabricated progress.
5. Skeleton is static, excluded from semantics, and has a single caller-supplied loading announcement.

## Public Interfaces

All paths below are relative to `apps/client/lib/shared/widgets/`.

| File | Interface |
|---|---|
| `loading_button.dart` | `enum BookletButtonVariant { primary, secondary, tertiary, destructive }`; `LoadingButton({required String label, VoidCallback? onPressed, bool isLoading = false, IconData? icon, String? errorText, BookletButtonVariant variant = BookletButtonVariant.primary})` |
| `booklet_chip.dart` | `enum BookletChipKind { difficulty, skill, filter }`; `BookletChip({required String label, BookletChipKind kind = BookletChipKind.skill, bool selected = false, ValueChanged<bool>? onSelected, IconData? icon})`; filter is controlled, other kinds are read-only. |
| `booklet_banner.dart` | `enum BookletBannerKind { info, warning, offline }`; `BookletBanner({required String message, BookletBannerKind kind = BookletBannerKind.info, String? actionLabel, VoidCallback? onAction})` |
| `booklet_overlays.dart` | `Future<T?> showBookletDialog<T>({required BuildContext context, required WidgetBuilder builder, bool barrierDismissible = true})`; `Future<T?> showBookletSheet<T>({required BuildContext context, required WidgetBuilder builder})`; `ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showBookletSnackBar({required BuildContext context, required String message, String? actionLabel, VoidCallback? onAction})` |
| `booklet_dialog.dart` | `BookletDialog({required String title, required Widget content, List<Widget> actions = const []})`, a scrollable AlertDialog using booklet sizing. |
| `booklet_progress.dart` | `BookletProgress({required String label, double? value, String? valueLabel})`; thin linear progress, accessible label, optional caller-provided valueLabel. |
| `booklet_skeleton.dart` | `BookletSkeleton({String label = 'Loading content'})`, static question/loading placeholder with a single semantics label. |
| `empty_state.dart` | `EmptyState({required String title, required String message, IconData icon = Icons.quiz_outlined, String? actionLabel, VoidCallback? onAction})` |
| `error_retry.dart` | `ErrorRetry({required String title, required String message, required VoidCallback onRetry, bool isRetrying = false, String? secondaryLabel, VoidCallback? onSecondary})` |
| `booklet_status_frame.dart` | Internal shared ruled status layout for EmptyState and ErrorRetry, receiving icon/title/message/actions; avoids duplicated structure. |

## Task 1 — Buttons, chips and banners

**Owner:** controls implementer. **Files:** first three production files above.
**Tests:** `test/shared/widgets/booklet_controls_test.dart` (test-writer).

- [x] Write deterministic widget tests for each variant, callbacks, disabled/loading suppression, chip selection, live banner message, action pairs and 360/2×.
- [x] Parent runs tests before production exists; expected missing imports/classes.
- [x] Implement native button styles from theme; loading keeps label and role colors, exposes loading semantics, and uses token spinner dimensions.
- [x] Use FilterChip for controlled filters with 48px hit target; skill/difficulty tags are noninteractive, labelled and adapt in height.
- [x] Render ruled banners with role icon/background, live semantics and actions below text when compact.
- [x] Parent runs targeted tests; expected PASS.

```dart
testWidgets('F-4: loading prevents duplicate action', (tester) async {
  var calls = 0;
  await tester.pumpWidget(MaterialApp(home: Scaffold(body:
    LoadingButton(label: 'Check answer', isLoading: true,
      onPressed: () => calls++))));
  await tester.tap(find.text('Check answer'));
  expect(calls, 0);
});
```

## Task 2 — Overlays and status components

**Owner:** feedback implementer. **Files:** other seven production files above.
**Tests:** `test/shared/widgets/booklet_feedback_test.dart` (test-writer).

- [x] Write widget tests for dialog/sheet returned results/dismissal, scrolling at 360/2×, snackbar actions, progress edge inputs, static skeleton and status actions.
- [x] Parent runs tests before production exists; expected missing imports/classes.
- [x] Implement safe native modal helpers, scrollable BookletDialog and snackbar using theme; no delayed work owned by helpers.
- [x] Render null progress indeterminately; invalid numeric values render as indeterminate, finite values clamp to [0,1]. Never compute completion from business data.
- [x] Implement static skeleton geometry from §8.7 with token dimensions, a single loading announcement and no shimmer.
- [x] Implement the ruled status frame, EmptyState secondary action and ErrorRetry primary/secondary actions. Long copy wraps; retry loading suppresses activation.
- [x] Parent runs targeted tests; expected PASS.

```dart
testWidgets('F-4: retry requests the caller action', (tester) async {
  var retries = 0;
  await tester.pumpWidget(MaterialApp(home: Scaffold(body:
    ErrorRetry(title: "This topic didn't load",
      message: 'Check your connection and try again.',
      onRetry: () => retries++))));
  await tester.tap(find.text('Retry'));
  expect(retries, 1);
});
```

## Task 3 — Tokens, goldens and verification

**Owner:** parent for tokens and verification; test-writer for golden tests.
**Files:** `core/theme/booklet_tokens.dart`, `test/goldens/components/feedback_golden_test.dart`, its generated PNGs, golden README.

- [x] Add shared component dimensions: spinner20, progress4, status icon32, chip visual32, dialog width400, skeleton label12/body20; use existing spacing/radius/stroke values.
- [x] Golden sheets: controls, statuses, overlays; 360/1280 light/dark and one 360/2× for each sheet. TickerMode disabled in test sheets, never update Components A images accidentally.
- [x] First golden comparison fails because baselines are absent; fix layout errors before freezing baselines.
- [x] Generate Windows baselines, open every PNG and compare with export geometry, glyphs and state roles.
- [x] Run golden comparisons, CI command `flutter test --exclude-tags golden`, and full `flutter test`.
- [x] Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze --fatal-infos`, `git diff --check`.
- [x] Review read-only for architecture, security, layout, semantics and motion; correct concrete findings with regression tests.
- [x] Record completed scope and next stage (AppShell); leave changes reviewable on current branch.

```dart
testWidgets('F-4: golden feedback_light_360_text2x', (tester) async {
  await expectGolden(tester, name: 'feedback_light_360_text2x', width: 360,
    textScale: 2, child: TickerMode(enabled: false, child: feedbackSheet()));
});
```
