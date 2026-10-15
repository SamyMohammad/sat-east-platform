# F-4 QuestionView PR 2 (quiz) Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development. The `test-writer` agent writes every `*_test.dart` (a project hook enforces this). `implementer` agents own disjoint production files. `code-reviewer` reviews the finished branch. Steps use checkbox syntax.

**Goal:** Add quiz mode to the shared `QuestionView`. It covers:
- the exam bar with the remaining time;
- a visible mark control;
- the question navigator (a popover on wide screens, a sheet on phone);
- the submit and time-up dialogs;
- quiz goldens.

**Architecture:**
- `QuestionView` stays stateless. A new `QuizMode` carries plain values that the quiz Cubit computes from an injected clock (`remaining`, `timeBudget`, `warnAt`, `timerHidden`). The widget never starts a timer.
- The enabled-state rules live in the `QuestionViewModeGating` extension (ruling R8), so the footer and shortcuts cannot drift apart.
- Overlays go through `booklet_overlays.dart`. The new `showBookletPopover` is built on `showDialog`, which brings Esc, barrier dismiss and the focus trap.
- PR 1's navigator grid and submit dialog are generalised and reused, not copied.

**Tech Stack:** Flutter 3.44.1, Dart 3.12.1, flutter_test. No dependencies added.

**Spec:** `docs/superpowers/specs/2026-10-14-f4-questionview-design.md` §1, §4, §5, §7, plus the deltas below. Patterns and rulings come from the PR 1 plan, `docs/superpowers/plans/2026-10-14-f4-questionview-pr1.md`.

**Design source:** `docs/design/claude-design-export/QuestionView.dc.html`:
- quiz VIEWS `quiz` / `quizwarn` / `quiznav`;
- markup blocks `mPhone` / `mWide` (exam bar), `examHeader`, `footMPhone` / `footMWide`, `navWide` / `navPhone`, `isWarn`, `dlgTimeup`.

Index page: `QuestionView Homework Quiz Review.dc.html` Q1–Q3.

## Step 0 — after plan approval

- [ ] PR #22 is merged (2026-10-14). Run `git checkout main && git pull`, then `git checkout -b feat/F-4-questionview-pr2`.
- [ ] Copy this file to `docs/superpowers/plans/2026-10-15-f4-questionview-pr2.md`.
- [ ] Update `docs/STATUS.md`:
  - Plan column → the PR 2 plan.
  - Branch → `feat/F-4-questionview-pr2`.
  - State → "PR 1 merged (#22); PR 2 quiz in progress".
  - Remove the open "wide HW legend" call: it is resolved by delta 6.
- [ ] Commit `docs(F-4): QuestionView PR 2 plan` on the feature branch, so the plan travels with the PR.

## Spec deltas (decided 2026-10-15)

1. **`QuizMode` fields beyond the spec:**
   - `title` ("Quiz 4.2": phone bar and navigator title).
   - `timeBudget` (the bar fills against it).
   - `warnAt` (warning threshold). The Cubit reads it from `settings`; the settings key is added by the quiz Cubit story.
   - `timerHidden`.
   - `answered` / `marked` as `Set<int>`, the same as `HomeworkMode` (the spec says `answeredIds` / `markedIds`).
2. **The 5-minute warning and Hide/Show timer are in quiz** (user call; the design Q1/Q2 show them).
   - Warning ⇔ `remaining <= warnAt`. The clock and bar turn `examBarWarning`, a `schedule` icon joins the clock, and a banner appears below the bar.
   - The banner copy comes from `warnAt`, never a literal "5".
   - While warning, the timer cannot be hidden: the Hide button is gone and `timerHidden` is ignored.
   - The phone bar has no Hide button (design) and always shows the clock.
3. **Exam bar tools are left out:** Reference, Desmos, More and the Directions dropdown. Mock adds an actions slot later.
4. **Submit entry:**
   - The navigator's bottom button reads "Submit quiz".
   - On the last question, the footer primary is "Submit quiz" instead of "Next".
   - Both open the confirm dialog: "Submit quiz?", with unanswered chips as in homework.
   - On the last question, → does nothing: the keyboard never opens a dialog.
5. **Time-up:**
   - `remaining <= Duration.zero` locks everything: choices, SPR, Back, Next, Submit, the mark toggle and its shortcuts.
   - The widget shows no dialog by itself. Features call the exported `showQuizTimeUpDialog` from their `BlocListener`.
   - That function first pops any open popup routes (sheet, popover, confirm).
   - The dialog is not dismissible (no barrier tap, no Back) and has a single "Continue".
6. **Navigator legend:** every navigator (homework panel, sheets, popover) shows all four entries, including "Marked for review". This resolves the PR 1 open call. `qv_homework_1280` regenerates.
7. **Left out of the design, on purpose:**
   - The ABC eliminator toggle. Per-tile cross-out and Shift+A–D already work in every mode, and the toggle would need new state.
   - The laptop keyboard-hint strip in the footer. It advertises an "E eliminator" key that does not exist.
8. **The banner's "Review marked" button** opens the navigator (popover or sheet). It is shown only when `marked` is non-empty.
9. **Quiz shows no `ExerciseHeader`.** The body starts with `QuizQuestionHeader`: a 32 px ink number badge plus the Mark toggle (the visible mark control deferred from PR 1, delta 5).
10. **Quiz has no `onBack` / exit.** The exit confirmation is mock-only.

## Global Constraints

These are unchanged from PR 1:
- English UI copy. Content goes through `MathText` only (rule 8).
- Domain types import only `package:flutter/foundation.dart`. No key, explanation or misconception reaches quiz types (rule 1).
- Sizes and colours come from `BookletSpace` / `BookletSize` / `BookletRadius` / `BookletStroke` / the theme / `context.booklet`. New sizes go in `booklet_tokens.dart`. No magic numbers. Touch targets are ≥ 48 px, except the design's 40 px exam toggles, which get a 48 px hit area via `minimumSize`.
- Breakpoints use `BookletLayout.forWidth`:
  - `compact` (≤ 600) gets the phone bar, footer and sheet.
  - `medium` / `expanded` get the wide bar, footer and popover.
- Overlays only through `showBookletDialog` / `showBookletSheet` / the new `showBookletPopover`. No `Navigator.push`.
- No timers, no network, and no `setState` outside `_SprAnswerArea`.
- Test names start with `F-4:`. Goldens are tagged `golden` with Windows baselines.
- Every existing golden except `qv_homework_1280` stays byte-identical.

## Review Focus

1. **Time-up while an overlay is open.** With the popover, sheet or submit dialog open, `showQuizTimeUpDialog` closes them and shows exactly one dialog. Barrier tap and Esc / system Back do not dismiss it. "Continue" fires once. → Task 2 test.
2. **Clock edge values.** `formatClock` covers:
   - negative → "00:00";
   - 280.2 s → "04:41" (ceil);
   - 0 → "00:00";
   - 3600 s → "60:00";
   - 4000 s → "66:40".

   Digits use tabular figures. The budget fill clamps to 0..1, and `timeBudget <= 0` → full. → Task 1 test.
3. **Screen readers and the clock.** The clock is not a live region, so it is not announced every tick. Only the warning banner is (`liveRegion: true`). The Mark toggle exposes `Semantics(toggled:)`. → Task 1 test.
4. **Exam bar at 360 / 2× text.** A long title ellipsizes, the clock is never clipped, and nothing overflows. → Task 1 test.
5. **Last question and time-up gating.**
   - Last question: primary "Submit quiz", → no-op.
   - At `remaining == 0`: A–D, Shift+A–D, M, ← and → fire nothing; the footer buttons are disabled; SPR is `disabled`.

   → Task 3 test.

## Public interfaces

All paths are relative to `apps/client/lib/shared/widgets/question_view/`.

```dart
// question_view_mode.dart (add)
final class QuizMode extends QuestionViewMode {
  const QuizMode({
    required this.title,        // "Quiz 4.2"
    required this.index,        // 0-based
    required this.total,
    required this.remaining,
    required this.timeBudget,   // e.g. 18:00 = 12 × 1.5 min
    required this.warnAt,       // from settings, via the Cubit
    this.timerHidden = false,
    this.answered = const {},
    this.marked = const {},
  });
  final String title; final int index; final int total;
  final Duration remaining; final Duration timeBudget; final Duration warnAt;
  final bool timerHidden; final Set<int> answered; final Set<int> marked;
}

extension QuestionViewModeGating on QuestionViewMode {
  bool get isTimeUp;            // QuizMode && remaining <= Duration.zero
  bool get isWarning;           // QuizMode && remaining <= warnAt
  bool get choicesInteractive;  // QuizMode → !isTimeUp
  VoidCallback? forwardAction(VoidCallback? onNext);  // QuizMode → !isTimeUp && index < total-1
  VoidCallback? backAction(VoidCallback? onPrev);     // QuizMode → !isTimeUp && index > 0
  VoidCallback? markAction(VoidCallback? onMark);     // QuizMode → isTimeUp ? null : onMark; others → onMark
  VoidCallback? submitAction(VoidCallback? onSubmit); // Homework → onSubmit; Quiz → isTimeUp ? null : onSubmit; Practice → null
}

// question_view.dart: one new optional callback
final VoidCallback? onToggleTimer;   // Hide/Show (wide only)

// parts/exam_clock.dart: pure, unit-tested
String formatClock(Duration remaining);          // ceil to whole seconds, clamp ≥ 0, "MM:SS", minutes unbounded
double budgetFraction(Duration remaining, Duration budget); // (budget-remaining)/budget clamped 0..1; budget<=0 → 1

// parts/exam_bar.dart
class ExamBar extends StatelessWidget {
  const ExamBar({required String title, required String shortTitle, required String subtitle,
    required Duration remaining, required Duration timeBudget, required bool warning,
    required bool timerHidden, required bool compact, VoidCallback? onToggleTimer, super.key});
}
class ExamWarningBanner extends StatelessWidget {
  const ExamWarningBanner({required Duration warnAt, VoidCallback? onReviewMarked, super.key});
}

// parts/quiz_question_header.dart
class QuizQuestionHeader extends StatelessWidget {
  const QuizQuestionHeader({required int number, required bool marked, VoidCallback? onMark, super.key});
}

// parts/question_navigator.dart (grid + legend moved out of homework_navigator.dart)
class QuestionNavigatorGrid extends StatelessWidget { /* same API as HomeworkNavigatorGrid */ }
class NavigatorLegend extends StatelessWidget { const NavigatorLegend({super.key}); } // 4 entries always
Future<void> showNavigatorSheet(BuildContext context, {required String title, required int total,
  required int index, required Set<int> answered, required Set<int> marked,
  required ValueChanged<int>? onJumpTo, required String submitLabel, required VoidCallback? onSubmitPressed});
Future<void> showNavigatorPopover(BuildContext context, { /* same params */ });

// parts/submit_dialog.dart (renamed from homework_submit_dialog.dart)
Future<void> showSubmitConfirmDialog(BuildContext context, {required String title, required String body,
  required String confirmLabel, required int total, required Set<int> answered,
  required VoidCallback? onSubmit, required ValueChanged<int>? onJumpTo});

// quiz_time_up_dialog.dart (top level: features import it)
Future<void> showQuizTimeUpDialog(BuildContext context,
  {required String title, required int answered, required VoidCallback onContinue});

// lib/shared/widgets/booklet_overlays.dart (add)
Future<T?> showBookletPopover<T>({required BuildContext context, required WidgetBuilder builder,
  required double width, required double bottomOffset, required String barrierLabel});
```

### Copy

| Where | Text |
|---|---|
| Wide bar | `QuestionView.title` ("Quiz · 4.2 Linear equations"); clock "MM:SS"; button "Hide" (semantics "Hide timer") |
| Wide bar, hidden | `timer_off` + "Timer hidden"; button "Show" (semantics "Show timer") |
| Phone bar | `QuizMode.title` + subtitle "{total} questions"; clock |
| Clock semantics | "Time left {MM:SS}" (not a live region) |
| Warning banner | **"{n} minutes left."** (singular "1 minute left.") + " Answer the rest; a guess scores better than a blank." + "Review marked". n = ceil(`warnAt` / 1 min) |
| Quiz header | badge "{index+1}"; toggle "Mark for review" (`bookmark_border`) / "Marked for review" (`bookmark`, `highlighter` fill) |
| Footer | phone: "Back" · "Question {i+1} of {total}" + `expand_less` (opens sheet) · "Next" / "Submit quiz"; wide: centre dark ink button "Question {i+1} of {total}" + `expand_less` (opens popover), right "Back" + "Next" / "Submit quiz" |
| Navigator | title "{QuizMode.title} questions"; legend Current / Answered / Unanswered / Marked for review; bottom outlined "Submit quiz"; close button tooltip "Close navigator" |
| Submit dialog | "Submit quiz?" / "After you submit, your answers are locked and marked." / chips as homework / "Keep working" + "Submit quiz" |
| Time-up dialog | `schedule` icon in `warning`; "Time's up. {title} submitted." / "Your {n} answers were saved and submitted automatically. Unanswered questions count as incorrect." (n == 1 → "Your 1 answer was …") / "Continue" |

Homework keeps its copy byte-identical. It calls `showSubmitConfirmDialog(title: 'Submit homework?', body: 'You can submit once. After that your answers are locked and marked.', confirmLabel: 'Submit homework', …)`.

## File map

| Path (under `apps/client/`) | Task | Responsibility |
|---|---|---|
| `lib/core/theme/booklet_tokens.dart` (modify) | 1, 2 | `examBarCompact = 56`, `examBarWide = 76`, `examBudgetCompact = 96`, `examBudgetWide = 200`, `examBudgetThinThickness = 3`, `examToggleHeight = 40`, `examTimerButtonHeight = 32`, `examQuestionBadge = 32`, `navigatorPopover = 456`, `warningBannerMinHeight = 56` |
| `lib/shared/widgets/question_view/parts/{exam_clock,exam_bar,quiz_question_header}.dart` (new) | 1 | clock maths, bar + banner, mark toggle |
| `lib/shared/widgets/booklet_overlays.dart` (modify) | 2 | `showBookletPopover` |
| `lib/shared/widgets/question_view/parts/question_navigator.dart` (new) | 2 | grid, legend, sheet, popover |
| `lib/shared/widgets/question_view/parts/homework_navigator.dart` (modify) | 2 | panel only; uses `QuestionNavigatorGrid`, `NavigatorLegend`, `showNavigatorSheet` |
| `lib/shared/widgets/question_view/parts/submit_dialog.dart` (rename via `git mv` from `homework_submit_dialog.dart`) | 2 | generic confirm |
| `lib/shared/widgets/question_view/quiz_time_up_dialog.dart` (new) | 2 | time-up |
| `lib/shared/widgets/question_view/{question_view_mode,choice_states,question_view}.dart`, `parts/{question_body,question_shortcuts}.dart` (modify) | 3 | `QuizMode` + wiring |
| `test/shared/widgets/question_view/{exam_bar_test,quiz_overlays_test,question_view_quiz_test}.dart` (new), `question_view_homework_test.dart`, `question_types_test.dart` (modify) | 1–3 | tests (test-writer) |
| `test/goldens/question_view/question_view_golden_test.dart` + baselines, `test/goldens/README.md`, `docs/STATUS.md` | 4 | goldens, status |

---

## Task 1 — Clock maths, exam bar, warning banner, quiz question header

**Files:** `parts/exam_clock.dart`, `parts/exam_bar.dart`, `parts/quiz_question_header.dart`, tokens. **Test:** `test/shared/widgets/question_view/exam_bar_test.dart`.

**Consumes:** `context.booklet` (`examBar`, `onExamBar`, `onExamBarVariant`, `examBarRule`, `examBarPrimary`, `examBarWarning`, `warning`, `warningContainer`, `highlighter`, `onHighlighter`).

**Produces:** `formatClock`, `budgetFraction`, `ExamBar`, `ExamWarningBanner`, `QuizQuestionHeader`, as in *Public interfaces*.

Reference implementation for the pure part:

```dart
String formatClock(Duration remaining) {
  final ms = remaining.inMilliseconds;
  final total = ms <= 0 ? 0 : (ms / Duration.millisecondsPerSecond).ceil();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(total ~/ 60)}:${two(total % 60)}';
}

double budgetFraction(Duration remaining, Duration budget) {
  if (budget <= Duration.zero) return 1;
  return ((budget - remaining).inMilliseconds / budget.inMilliseconds)
      .clamp(0.0, 1.0);
}
```

Layout:
- **Phone bar** (`compact: true`):
  - `examBar` background, `SafeArea(bottom: false)`, row height `examBarCompact`.
  - Left `Expanded`: `shortTitle` (titleSmall w600, 1 line, ellipsis) over `subtitle` (labelSmall, `onExamBarVariant`).
  - Centre: clock (titleMedium w600, `FontFeature.tabularFigures()`) over a `examBudgetCompact × examBudgetThinThickness` track (`examBarRule`) with the fill.
  - Right: an empty `Expanded`, so the clock stays centred.
- **Wide bar:**
  - Height `examBarWide`, padding start `s6` / end `s3`.
  - Start `Expanded`: `title` (titleMedium w600, ellipsis).
  - Centre: a `Row` holding the clock (titleLarge w600, tabular) and an `OutlinedButton` "Hide" (height `examTimerButtonHeight`, `examBarRule` border, `onExamBar` text) under `examBudgetWide × progressThickness`.
  - End: an empty `Expanded`.
  - Hidden: `timer_off` + "Timer hidden" (`onExamBarVariant`) + "Show". The bar still shows.
  - Hide/Show is shown only when `onToggleTimer != null && !warning`.
- **Warning:** clock text + fill use `examBarWarning`, and a filled `Icons.schedule` precedes the clock. `timerHidden` is ignored.
- **Clock semantics:** `Semantics(label: 'Time left ${formatClock(remaining)}', child: ExcludeSemantics(...))`, with no `liveRegion`.
- **`ExamWarningBanner`:**
  - `warningContainer` background, bottom border `warning`, min height `warningBannerMinHeight`.
  - `Wrap` holding the icon, `Text.rich` with the bold first sentence, and "Review marked" as a `TextButton`, only when `onReviewMarked != null`.
  - Wrapped in `Semantics(container: true, liveRegion: true)`.
- **`QuizQuestionHeader`:**
  - `Row`: badge `examQuestionBadge` square (`scheme.onSurface` fill, `scheme.surface` text, w700, `BookletRadius.xs`), the toggle, then `Spacer`. The bottom border uses `outlineVariant` with `s3` padding, as in `ExerciseHeader`.
  - Toggle: `OutlinedButton.icon`, visual height `examToggleHeight`, `minimumSize` height `touchTarget`.
  - Marked: `highlighter` fill, `onHighlighter` text, and the filled `bookmark` icon.
  - `Semantics(toggled: marked, button: true)`. `onPressed: onMark`, so null disables it.

Steps:
- [ ] test-writer writes `exam_bar_test.dart`:
  1. `formatClock` and `budgetFraction`: every value in Review Focus 2, plus `budgetFraction(9:00 of 18:00) == 0.5`.
  2. Phone bar: it shows the short title, the subtitle and the clock, and has no Hide button even with `onToggleTimer` set.
  3. Wide bar: "Hide" fires `onToggleTimer`. `timerHidden` shows "Timer hidden" + "Show" and no clock text.
  4. Warning: the clock colour equals `examBarWarning` (read the `Text` style), the `schedule` icon is present, and Hide is absent even when `timerHidden: true`, in which case the clock is shown.
  5. Semantics: the clock node label is "Time left 14:30" and is not a live region. The banner node is a live region.
  6. Banner copy: `warnAt` 5 min gives "5 minutes left."; 1 min gives "1 minute left."; 90 s gives "2 minutes left.". "Review marked" fires its callback and is absent when the callback is null.
  7. `QuizQuestionHeader`: badge text "4". The unmarked label "Mark for review" fires `onMark`. Marked shows "Marked for review" with `toggled: true` semantics. A null `onMark` disables the toggle.
  8. **Review Focus 4:** `ExamBar(compact: true)` with a 60-character title at 360 px / `textScaler 2.0` has no exception, and the clock text is fully visible (`tester.getRect` lies within the bar).
- [ ] Run `flutter test test/shared/widgets/question_view/exam_bar_test.dart`. Expected: FAIL (missing files).
- [ ] Implement as above. Run the test again: PASS. Run `flutter analyze --fatal-infos`.
- [ ] Commit `feat(F-4): quiz exam bar, warning banner and mark toggle`.

## Task 2 — Overlays: popover, shared navigator, submit and time-up dialogs

**Files:** `booklet_overlays.dart`, `parts/question_navigator.dart` (new), `parts/homework_navigator.dart`, `parts/submit_dialog.dart` (`git mv` from `homework_submit_dialog.dart`), `quiz_time_up_dialog.dart`, tokens. Update the imports in `question_view.dart`. **Tests:** `quiz_overlays_test.dart` (new), `question_view_homework_test.dart` (modify).

**Consumes:** the PR 1 grid, legend and submit-dialog code (move it, do not copy it).

**Produces:** `showBookletPopover`, `QuestionNavigatorGrid`, `NavigatorLegend`, `showNavigatorSheet`, `showNavigatorPopover`, `showSubmitConfirmDialog`, `showQuizTimeUpDialog`.

**`showBookletPopover`** is `showDialog` with:
- `barrierColor: Colors.transparent`, `barrierDismissible: true`, `barrierLabel`.
- `animationStyle` the same as `showBookletDialog`.
- Builder: `SafeArea` → `Align(alignment: Alignment.bottomCenter)` → `Padding(bottom: bottomOffset)` → `ConstrainedBox(maxWidth: width)` → `Material(color: surface, shape: RoundedRectangleBorder(BookletRadius.md, side: outlineVariant), elevation from theme dialog / `overlayShadow`)` → `Padding(fromLTRB(s5, s4, s5, s5))`.
- `showNavigatorPopover` passes `bottomOffset: BookletSize.footerHeight + BookletSpace.s3` and `width: BookletSize.navigatorPopover`.

**Navigator content** (shared by the sheet and the popover):
- Title row: the title plus, in the popover only, a close `IconButton` with tooltip "Close navigator". The sheet already has "Close sheet".
- `NavigatorLegend`, then a divider.
- `QuestionNavigatorGrid`: columns 7 in the popover, 6 in the sheet.
- An outlined `submitLabel` button. Tapping a cell pops and then calls `onJumpTo(i)`. The submit button pops and then calls `onSubmitPressed` (guard `context.mounted`, as PR 1 does).
- `showHomeworkNavigatorSheet` becomes a thin wrapper:

  ```dart
  showNavigatorSheet(
    context,
    title: title,
    submitLabel: 'Submit homework',
    onSubmitPressed: onSubmit == null
        ? null
        : () => showSubmitConfirmDialog(context, title: 'Submit homework?', ...),
    ...
  );
  ```

- `HomeworkNavigatorPanel` uses `NavigatorLegend()`: delta 6, so "Marked for review" now shows.

**`showQuizTimeUpDialog`:**

```dart
Future<void> showQuizTimeUpDialog(BuildContext context,
    {required String title, required int answered, required VoidCallback onContinue}) {
  Navigator.of(context).popUntil((route) => route is! PopupRoute);
  final body = answered == 1
      ? 'Your 1 answer was saved and submitted automatically.'
      : 'Your $answered answers were saved and submitted automatically.';
  return showBookletDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => PopScope(
      canPop: false,
      child: BookletDialog(
        title: "Time's up. $title submitted.",
        // BookletDialog has no icon slot (title/content/actions only).
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: BookletSpace.s3,
          children: [
            Icon(Icons.schedule, size: BookletSize.statusIcon,
                color: dialogContext.booklet.warning),
            Text('$body Unanswered questions count as incorrect.'),
          ],
        ),
        actions: [LoadingButton(label: 'Continue', onPressed: () {
          Navigator.of(dialogContext).pop();
          onContinue();
        })],
      ),
    ),
  );
}
```

Steps:
- [ ] test-writer:
  - **Updates `question_view_homework_test.dart`:** flip line 205 to `findsOneWidget` ("Marked for review" in the wide panel), and import from `submit_dialog.dart`.
  - **Writes `quiz_overlays_test.dart`:**
    1. The popover opens above the footer, with width ≤ `navigatorPopover` and 7 columns (cell 7 shares a row with cell 1, cell 8 does not). A barrier tap closes it, Esc closes it, and the close button closes it.
    2. In the popover and the sheet, a cell tap pops and calls `onJumpTo(i)` once. "Submit quiz" pops and calls `onSubmitPressed` once.
    3. Every legend shows 4 entries.
    4. `showSubmitConfirmDialog` with quiz copy shows the title, body, chips for the unanswered indices and both actions. Confirm calls `onSubmit` once. A chip pops and jumps.
    5. **Review Focus 1:** open the popover (and separately the sheet, and the submit dialog), then call `showQuizTimeUpDialog`. Exactly one dialog route is open, and the popover/sheet content is gone. A barrier tap and `tester.binding.handlePopRoute()` leave it open. "Continue" fires once and closes it.
    6. Time-up copy: "Your 1 answer was saved …" for 1, "Your 9 answers were saved …" for 9, and the title "Time's up. Quiz 4.2 submitted.".
- [ ] Run `flutter test test/shared/widgets/question_view`. Expected: FAIL (new symbols, and the flipped legend assertion).
- [ ] Implement it: move the grid and legend, add the popover, rename the dialog, add time-up.
- [ ] Run `flutter test test/shared/widgets/question_view`: PASS. Run `flutter test test/goldens --tags golden`: only `qv_homework_1280` fails, and only because of the legend line. Do not update goldens yet; Task 4 does it.
- [ ] Commit `feat(F-4): navigator popover, shared navigator and quiz dialogs`.

## Task 3 — `QuizMode` and `QuestionView` quiz wiring

**Files:** `question_view_mode.dart`, `choice_states.dart`, `question_view.dart`, `parts/question_body.dart`, `parts/question_shortcuts.dart` (the mark gate only). **Tests:** `question_view_quiz_test.dart` (new), plus gating cases in `question_types_test.dart` and `choice_states_test.dart`.

**Consumes:** everything from Tasks 1–2.

**Produces:** `QuizMode`, the gating additions, `QuestionView.onToggleTimer`.

Exhaustive-switch sites and the quiz value for each:

| Site | Quiz |
|---|---|
| `choicesInteractive` | `!isTimeUp` |
| `forwardAction` | `!isTimeUp && index < total - 1 ? onNext : null` |
| `backAction` | `!isTimeUp && index > 0 ? onPrev : null` |
| `markAction` (new) | `isTimeUp ? null : onMark` (practice/homework → `onMark`) |
| `submitAction` (new) | `isTimeUp ? null : onSubmit` |
| `choiceLookFor` | `QuizMode() => working` |
| `QuestionBody._sprState` | `isTimeUp ? SprInputState.disabled : SprInputState.editable` |
| `QuestionBody` column head | `QuizQuestionHeader(number: index + 1, marked: answer.marked, onMark: mode.markAction(onMark))` instead of `ExerciseHeader` (add an `onMark` param to `QuestionBody`) |
| `QuestionView._header` | `Column[ExamBar(...), if (mode.isWarning) ExamWarningBanner(warnAt, onReviewMarked: marked.isEmpty ? null : () => _openNavigator(context, layout))]` |
| `QuestionView._bodyWithPanel` | the body only (no side panel) |
| `QuestionView._footer` | see below |
| `QuestionShortcuts` | `onMark: mode.markAction(onMark)` |

`_header` needs `context` and `layout`, so change its signature to `_header(BuildContext context, BookletLayout layout)`. The practice and homework arms ignore them.

Quiz footer:
- `final last = index == total - 1`.
- primary:

  ```dart
  last
      ? LoadingButton(
          label: 'Submit quiz',
          onPressed: _confirmSubmit(context) /* null if submitAction null */,
        )
      : LoadingButton(label: 'Next', onPressed: mode.forwardAction(onNext))
  ```

- leading: "Back" (secondary, `backAction`).
- middle on phone: the same `TextButton` + `expand_less` as homework, opening `showNavigatorSheet`.
- middle on wide: a `FilledButton` (`scheme.onSurface` background, `scheme.surface` foreground) labelled "Question {i+1} of {total}" + `expand_less`, opening `showNavigatorPopover`.
- The wide layout needs Back + primary together on the right. Pass `leading: null` and `primary: Row(mainAxisSize: min, spacing: s3, [Back, primary])` at wide widths. That makes no `QuestionFooter` API change.
- `_openNavigator(context, layout)` picks the sheet or the popover. It passes `title: '${quiz.title} questions'`, `submitLabel: 'Submit quiz'`, and `onSubmitPressed: _confirmSubmit(context)`.
- `_confirmSubmit` returns null when `mode.submitAction(onSubmit)` is null. Otherwise it opens `showSubmitConfirmDialog` with the quiz copy.
- A navigator cell tap → `onJumpTo` stays enabled until time-up. At time-up, pass `onJumpTo: null`.

Steps:
- [ ] test-writer writes `question_view_quiz_test.dart`, at 360 and 1280:
  1. Chrome: the phone bar shows "Quiz 4.2" / "12 questions" / "14:30". The wide bar shows the full title + "Hide", which fires `onToggleTimer`. Neither width shows an `ExerciseHeader`, and `QuizQuestionHeader` shows "4".
  2. Mark: tapping the toggle and pressing `M` both fire `onMark`. `answer.marked: true` shows "Marked for review".
  3. Navigator: the phone footer button opens the sheet and the wide centre button opens the popover. Cells reflect answered/marked. A tap jumps.
  4. Submit: the navigator's "Submit quiz" leads to the confirm dialog, whose confirm fires `onSubmit` once. On the last question, the primary reads "Submit quiz" and opens the same dialog. "Next" is absent there.
  5. Warning: `remaining` 4:41 with `warnAt` 5:00 shows the banner. "Review marked" opens the navigator when `marked` is non-empty and is absent when empty. At 5:01 there is no banner.
  6. **Review Focus 5:** last question: → fires nothing. Time-up (`remaining: Duration.zero`, SPR and MCQ variants): taps on tiles fire nothing; A, Shift+B, M, ← and → fire nothing; Back, Next/Submit and the Mark toggle are disabled; `SprInput` state is `disabled`.
  7. Resizing from 1280 to 360 swaps the popover button for the sheet button, and callbacks still fire.
  8. No feedback appears in quiz: no `MarginNote`, `HintPanel` or `WorkedExample`.
- [ ] test-writer adds the gating unit cases (`isTimeUp`, `isWarning` boundary at `== warnAt`, `forwardAction` / `backAction` / `markAction` / `submitAction` for every mode) and a `choiceLookFor` quiz row.
- [ ] Run `flutter test test/shared/widgets/question_view`. Expected: FAIL (`QuizMode` missing).
- [ ] Implement. Run the tests: PASS. Run `flutter analyze --fatal-infos`. Run the existing practice, homework and shortcut tests unchanged: PASS.
- [ ] Commit `feat(F-4): QuestionView quiz mode`.

## Task 4 — Goldens, verification, status

**Files:** `test/goldens/question_view/question_view_golden_test.dart` + baselines, `test/goldens/README.md`, `docs/STATUS.md`.

- [ ] Add these goldens, light, full viewport via `expectViewportGolden`, using the design data (Quiz 4.2, 12 questions, `timeBudget` 18:00, unanswered {7, 10} (1-based → indices 6, 9), marked {5} → index 4):
  - `qv_quiz_360`, `qv_quiz_1280`: Q4, `remaining` 14:30, B selected, D eliminated.
  - `qv_quiz_warning_360`, `qv_quiz_warning_1280`: Q11, 04:41, `warnAt` 5:00, marked, A selected.
  - `qv_quiz_navigator_360` (sheet open), `qv_quiz_navigator_1280` (popover open).
  - `qv_quiz_timer_hidden_1280`.
  - `qv_quiz_submit_1280` (confirm dialog with chips Q7, Q10).
  - `qv_quiz_timeup_360` (time-up dialog over the quiz at 00:00).
- [ ] Regenerate `qv_homework_1280` (legend delta 6). Every other existing PNG must be unchanged (`git status` shows only the new files + `qv_homework_1280.png`).
- [ ] The first run FAILs (no baselines). Then run `flutter test test/goldens --update-goldens --tags golden` on Windows, and open every new PNG against the design Q1–Q3.
- [ ] Run from `apps/client/`:

  ```powershell
  dart format --output=none --set-exit-if-changed .
  flutter analyze --fatal-infos
  flutter test --exclude-tags golden
  flutter test test/goldens --tags golden
  git diff --check
  ```

- [ ] Run `/flutter-code-quality:review-gate`, then `/flutter-code-review`, then the `code-reviewer` agent. Fix findings with regression tests.
- [ ] Update `docs/STATUS.md`: row → "PR 2 in review"; Next → gallery. Update `test/goldens/README.md` (count + scope). Run `graphify update .`.
- [ ] `git-expert`: commit, push, and open the PR `feat(F-4): QuestionView quiz mode` (CI green).

## Verification (end-to-end)

- Every command above is clean, and the goldens pass on Windows.
- No consumer route exists yet (the gallery comes after PR 2), so verification relies on widget tests at 360 / 768 / 1280 plus the golden PNGs, compared by eye against the `QuestionView Homework Quiz Review.dc.html` Q1–Q3 screens.
- No-timer check: `grep -rnE "\bTimer\(|Ticker|Stopwatch|periodic" lib/shared/widgets/question_view` finds nothing.
- Rule-1 check: the PR 1 contract test still passes. `QuizMode` has no key or explanation field.
