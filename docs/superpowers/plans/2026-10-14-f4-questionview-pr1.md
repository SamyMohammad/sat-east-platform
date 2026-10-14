# F-4 QuestionView PR 1 (core + practice + homework) Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development. The `test-writer` agent writes every `*_test.dart` (a project hook enforces this). `implementer` agents own disjoint production files. `code-reviewer` reviews the finished branch. Steps use checkbox syntax.

**Goal:** Ship the shared `QuestionView` widget in practice and homework modes, built on the merged booklet components.

**Architecture:**
- A stateless `QuestionView` in `apps/client/lib/shared/widgets/question_view/` renders plain values by mode and breakpoint, and reports interaction through callbacks.
- Feature Cubits (later stories) own state, saving, retries and timers.
- Small private-to-the-folder parts hold the chrome. The only local state is SPR keypad visibility and the last key hint (CLAUDE.md B.1).
- One pure function maps feedback to `ChoiceTileState`, so the mapping is unit-tested without widgets.

**Tech Stack:** Flutter 3.44.1, Dart 3.12.1, flutter_test. No dependencies added.

**Spec:** `docs/superpowers/specs/2026-10-14-f4-questionview-design.md` (§1–3, 5, 7), with the deltas below.

**Design source:** `docs/design/claude-design-export/QuestionView.dc.html` (practice/homework views), `QuestionView States.dc.html` (08–11, 13), `QuestionView Practice.dc.html`.

## Step 0 — after plan approval

- [ ] Copy this file to `docs/superpowers/plans/2026-10-14-f4-questionview-pr1.md`.
- [ ] Set the `docs/STATUS.md` Plan column to it.
- [ ] Commit both on `docs/F-4-questionview-spec` and push, so PR #21 carries spec + plan.
- [ ] Implementation branch: `feat/F-4-questionview-pr1` from `main` once #21 merges. Do not stack it on the docs branch.

## Spec deltas (decided 2026-10-14)

Each delta is a choice the user made or a design detail the spec did not cover.

1. **`ChoiceTile.statusLabel`**: an optional `String?` that overrides the trailing feedback label. The default labels are unchanged, so the existing ChoiceTile goldens stay as they are. It is used for "1st try" on the second miss.
2. **The first pick is carried in feedback.** `FirstMiss.missed` and `Revealed.firstTry` keep the first wrong answer visible after the student reselects.
3. **Header and exercise data:**
   - `QuestionView` takes `title` and `onBack`.
   - `QuestionData` takes `label` ("4.2 · Ex 7") and optional `difficulty` and `skill`.
   - `PracticeMode` takes `rep` and `repTarget`.
   - The widget formats the copy.
4. **Practice action row left out** (Ask AI, video, Report and the Hint toggle). The hint panel shows automatically on `FirstMiss` when `hintMd != null`.
5. **Homework mark:** no button. Marked cells appear in the navigator (phone legend "Marked for review"), and the `M` shortcut fires `onMark` when it is non-null. The visible mark control comes with the quiz exam bar (PR 2).
6. **Save status adds `failed`:** "Couldn't save" plus a Retry button calling `onRetrySave` (States 11). The 400 ms "Saving…" delay belongs to the Cubit; the widget never runs a timer.
7. **Margin note author** is the caller-supplied `noteAuthor` (e.g. the teacher name from settings), never a literal.
8. **Homework submit confirmation** is `showBookletDialog` + `BookletDialog`:
   - Unanswered chips are the indices in `0..total-1` missing from `answered`.
   - Tapping a chip pops the dialog and calls `onJumpTo(i)`.
   - Confirming calls `onSubmit`.
9. **Out of `QuestionView`:**
   - The empty-filters view and the loading skeleton are feature-level and use the existing `EmptyState` and `BookletSkeleton`.
   - The figure zoom button is left out.
   - Figures come from a caller `figureBuilder`, so the widget never touches the network.
10. **Tile looks:**
    - "Dim" = `ChoiceTileState.reviewOther` (ink2 text). `disabled` uses the disabled ink, which is the wrong match.
    - `Checking` = `LoadingButton(isLoading: true)` with tiles non-interactive.

## Global Constraints

- English UI copy. Content (stem, choices, notes, hint, explanation) is rendered only through `MathText` (rule 8).
- Domain types import only `package:flutter/foundation.dart` (for `@immutable`) or nothing. `QuestionData` and its children have no key, explanation or misconception field (rule 1).
- All sizes and colours come from `BookletSpace` / `BookletSize` / `BookletRadius` / `BookletStroke` / the theme / `context.booklet`. Add any new size to `booklet_tokens.dart`; no magic numbers. Touch targets are ≥ 48 px.
- Breakpoints use `BookletLayout.forWidth(width)`:
  - `compact` (≤ 600) is phone.
  - The margin-note aside appears only at `expanded` (≥ 1024).
  - The homework side panel appears at `medium` and `expanded`.
- No `Navigator.push`. Overlays only through `showBookletDialog` / `showBookletSheet`.
- No timers, no network, and no `setState` outside `_SprAnswerArea`.
- Test names start with `F-4:`. Goldens are tagged `golden` with Windows baselines.

## Review Focus

1. **Shortcuts while typing.** Pressing A–D or ←/→ inside the SPR field must type or move the caret, never select or navigate. → Task 6 test.
2. **Shortcuts when locked.** Shortcuts during `Checking` / `Correct` / `Revealed` must not select, and Shift+letter on an absent choice (a 4-choice question with `E`) does nothing. → Task 6 tests.
3. **Long content at 360 / 2× text.** A long Arabic stem plus margin note plus hint must scroll, with no overflow. The footer stays pinned. → Task 4 test.
4. **SPR on the phone keypad.** Keys edit through `applySprKey`. A second slash shows the key hint and leaves the text unchanged. Hide/show works, and the system keyboard is not requested. → Task 3 test.
5. **Width changes.** Resizing from 1280 to 360 moves the navigator from the side panel to the footer sheet button, and moves the note from the aside to inline, with no lost callbacks. → Task 5 test.
6. **Screen readers.** The margin note is a live region, so it is announced when it appears, and red is never the only signal (pen icon + text). → Task 2 test.

## Public interfaces

All paths are relative to `apps/client/lib/shared/widgets/question_view/`.

```dart
// question_data.dart  — NO key / explanation / misconception (rule 1)
enum QuestionDifficulty { easy, medium, hard }
@immutable final class ChoiceData { const ChoiceData({required this.label, required this.md}); final String label; final String md; }
sealed class QuestionKind { const QuestionKind(); }
final class McqKind extends QuestionKind { const McqKind(this.choices); final List<ChoiceData> choices; }
final class SprKind extends QuestionKind { const SprKind(); }
@immutable final class QuestionData {
  const QuestionData({required this.id, required this.label, required this.stemMd,
    required this.kind, this.imagePaths = const [], this.difficulty, this.skill});
  final String id; final String label; final String stemMd; final QuestionKind kind;
  final List<String> imagePaths; final QuestionDifficulty? difficulty; final String? skill;
}

// answer_state.dart
@immutable final class AnswerState {
  const AnswerState({this.selected, this.eliminated = const {}, this.marked = false, this.sprText = ''});
  final String? selected; final Set<String> eliminated; final bool marked; final String sprText;
  bool get hasAnswer => selected != null || sprText.trim().isNotEmpty;
}

// practice_feedback.dart
sealed class AnswerKey { const AnswerKey(); }
final class McqAnswerKey extends AnswerKey { const McqAnswerKey(this.label); final String label; }
final class SprAnswerKey extends AnswerKey { const SprAnswerKey(this.text); final String text; } // NOT SprKey (taken by core/grading)
sealed class PracticeFeedback { const PracticeFeedback(); }
final class Idle extends PracticeFeedback { const Idle(); }
final class Checking extends PracticeFeedback { const Checking(); }
final class FirstMiss extends PracticeFeedback {
  const FirstMiss({required this.missed, this.noteMd, this.hintMd});
  final String missed; // MCQ label or SPR text of the 1st try
  final String? noteMd; final String? hintMd;
}
final class Correct extends PracticeFeedback {
  const Correct({this.noteMd, this.explanationMd, this.firstTry});
  final String? noteMd; final String? explanationMd; final String? firstTry;
}
final class Revealed extends PracticeFeedback {
  const Revealed({required this.key, required this.firstTry, this.noteMd, this.explanationMd});
  final AnswerKey key; final String firstTry; final String? noteMd; final String? explanationMd;
}

// question_view_mode.dart
enum SaveStatus { saving, saved, offline, failed }
sealed class QuestionViewMode { const QuestionViewMode(); }
final class PracticeMode extends QuestionViewMode {
  const PracticeMode({required this.feedback, required this.rep, required this.repTarget, this.noteAuthor});
  final PracticeFeedback feedback; final int rep; final int repTarget; final String? noteAuthor;
}
final class HomeworkMode extends QuestionViewMode {
  const HomeworkMode({required this.title, required this.index, required this.total,
    required this.saveStatus, this.answered = const {}, this.marked = const {}});
  final String title; // "Homework 4.2"
  final int index; // 0-based
  final int total; final SaveStatus saveStatus; final Set<int> answered; final Set<int> marked;
}

// choice_states.dart — pure, unit-tested
typedef ChoiceLook = ({ChoiceTileState state, String? statusLabel});
ChoiceLook choiceLookFor(String label, AnswerState answer, QuestionViewMode mode);

// question_view.dart
class QuestionView extends StatelessWidget {
  const QuestionView({required this.title, required this.question, required this.mode,
    required this.answer, super.key, this.onBack, this.onSelect, this.onEliminate,
    this.onRestore, this.onSprChanged, this.onCheck, this.onNext, this.onPrev, this.onMark,
    this.onJumpTo, this.onSubmit, this.onRetrySave, this.figureBuilder});
  final String title; final QuestionData question; final QuestionViewMode mode; final AnswerState answer;
  final VoidCallback? onBack; final ValueChanged<String>? onSelect, onEliminate, onRestore;
  final ValueChanged<String>? onSprChanged;
  final VoidCallback? onCheck, onNext, onPrev, onMark, onSubmit, onRetrySave;
  final ValueChanged<int>? onJumpTo;
  final Widget Function(BuildContext, String path)? figureBuilder;
}
```

### Choice mapping (`choiceLookFor`)

| Mode / feedback | This choice is… | Look |
|---|---|---|
| Homework or practice `Idle` | selected | `selected` |
| | eliminated | `eliminated` |
| | else | `idle` |
| `Checking` | selected | `selected` |
| | else | `disabled` |
| `FirstMiss` | `missed` | `incorrect` |
| | else | idle / selected / eliminated as in `Idle` |
| `Correct` | selected | `correct` |
| | `firstTry` | `incorrect`, label "1st try" |
| | else | `reviewOther` |
| `Revealed` (McqAnswerKey k) | `k.label` | `correctAnswer` |
| | `firstTry` | `incorrect`, label "1st try" |
| | selected | `incorrect`, label "Your answer" |
| | else | `reviewOther` |

### Interaction rules

- **Practice Check:**
  - Enabled iff `onCheck != null && answer.hasAnswer`. Under `FirstMiss`, also requires `answer.selected != missed` (MCQ) or `sprText != missed` (SPR).
  - When disabled under `FirstMiss`, the wide layout shows the helper "Pick another answer".
  - `Correct` / `Revealed` swap the primary to "Next" (`onNext`).
- **Tiles are interactive** only in homework, `Idle` and `FirstMiss`.
- **SPR state:**

  | Feedback | `SprInputState` | `correctAnswer` |
  |---|---|---|
  | `Correct` | `correct` | — |
  | `Revealed` | `incorrect` | the `SprAnswerKey` text |
  | `Checking` | `disabled` | — |
  | everything else | `editable` | never set |

## File map

| Path (under `apps/client/`) | Task | Responsibility |
|---|---|---|
| `lib/shared/widgets/choice_tile.dart` (modify) | 1 | add `statusLabel` |
| `lib/shared/widgets/question_view/{question_data,answer_state,practice_feedback,question_view_mode,choice_states}.dart` | 1 | types + mapping |
| `lib/shared/widgets/question_view/parts/{question_header,save_status_label,exercise_header,margin_note,hint_panel,worked_example}.dart` | 2 | chrome parts |
| `lib/shared/widgets/question_view/parts/{choice_list,spr_answer_area}.dart` | 3 | answer area |
| `lib/shared/widgets/question_view/{question_view.dart, parts/question_footer.dart, parts/question_body.dart}` | 4 | assembly + practice |
| `lib/shared/widgets/question_view/parts/{homework_navigator,homework_submit_dialog}.dart` | 5 | homework |
| `lib/shared/widgets/question_view/parts/question_shortcuts.dart` | 6 | keyboard |
| `lib/core/theme/booklet_tokens.dart` (modify) | 2–5 | new sizes: `marginNote = 300`, `navigatorPanel = 280`, `navigatorCell = 48`, `progressSegmentGap = 3`, `footerHeight = 72` |
| `test/shared/widgets/question_view/*_test.dart`, `test/goldens/question_view/` | all | tests (test-writer) |

---

## Task 1 — Types, choice mapping, `ChoiceTile.statusLabel`

**Files:** the five type files, `choice_tile.dart`. **Tests:** `test/shared/widgets/question_view/question_types_test.dart`, `choice_states_test.dart`, and an added case in `test/shared/widgets/choice_tile_test.dart`.

**Produces:** every type in *Public interfaces*, and `choiceLookFor`.

- [ ] test-writer writes the tests:
  - The rule-1 contract test below.
  - Every row of the choice-mapping table.
  - `AnswerState.hasAnswer`, including whitespace-only SPR text.
  - `statusLabel` replaces "Incorrect" with "1st try", and a null override keeps "Incorrect".
- [ ] Run `flutter test test/shared/widgets/question_view test/shared/widgets/choice_tile_test.dart`. Expected: FAIL (missing files).
- [ ] Implement the types exactly as in *Public interfaces*. In `ChoiceTile`, `_trailing` uses `widget.statusLabel ?? status.label`.
- [ ] Re-run the tests: PASS. Run `flutter test test/goldens/components --tags golden`: unchanged ChoiceTile goldens PASS.
- [ ] Commit `feat(F-4): QuestionView types and choice mapping`.

The rule-1 contract test reads the source, because Flutter tests have no mirrors:

```dart
test('F-4: QuestionData exposes no answer key, explanation or misconception', () {
  final src = File('lib/shared/widgets/question_view/question_data.dart')
      .readAsStringSync()
      .replaceAll(RegExp(r'//.*'), ''); // ignore comments
  for (final banned in ['key', 'answer', 'explanation', 'misconception', 'hint', 'correct']) {
    expect(RegExp('\\bfinal\\s+\\S+\\s+\\w*$banned\\w*\\s*;', caseSensitive: false).hasMatch(src),
        isFalse, reason: 'field containing "$banned" in QuestionData');
  }
});
```

## Task 2 — Header, save status, exercise header, notes and panels

**Files:** the Task 2 parts plus tokens. **Test:** `question_parts_test.dart`.

**Consumes:** `SaveStatus`, `QuestionDifficulty`.

**Produces:**
- `QuestionHeader({required String title, required String modeLabel, required String progressLabel, required int done, required int total, int? current, VoidCallback? onBack, Widget? trailing})`
- `SaveStatusLabel({required SaveStatus status, VoidCallback? onRetry})`
- `ExerciseHeader({required String label, QuestionDifficulty? difficulty, String? skill})`
- `MarginNote({required MarginNoteTone tone, required String? author, required String bodyMd})`, with `enum MarginNoteTone { miss, correct }`
- `HintPanel({required String md})`
- `WorkedExample({required String label, required String md})`

- [ ] test-writer tests:
  1. **Header, phone:** back (tooltip "Back to topic", fires `onBack`), title ellipsis, segment bar: `done` filled, `current` outlined, rest rule.
  2. **Header, wide:** the progress block sits on the right, and there is no overflow menu.
  3. **Save status:** each one shows its icon + copy: `cloud_done` "Saved", `progress_activity` "Saving…", `cloud_off` "Offline — will sync", `error` "Couldn't save" + "Retry" firing `onRetry`. It is wrapped in `Semantics(liveRegion: true)`.
  4. **Exercise header:** the label is uppercase. Difficulty chips read "E · Easy" / "M · Medium" / "H · Hard". Skill uses `BookletChip(kind: skill, icon: Icons.sell_outlined)`.
  5. **Margin note, miss:** `ink_pen` icon + author + body in `scheme.error`. **Correct:** `check_circle` + "Correct" in `booklet.greenTick`. Both have `Semantics(liveRegion: true)`. A null author shows the icon only.
  6. **Hint and worked example:** the hint shows "HINT"; the worked example shows "WORKED EXAMPLE · 4.2 · EX 7". Both render the body through `MathText`.
- [ ] Run the tests: FAIL. Implement with tokens and theme only, following the extracted geometry:
  - Phone header: 56 px row + progress block.
  - Wide header: 72 px, progress width 300.
  - Note: rule on the leading edge (aside) or top edge (inline). An `inline` bool decides which.
- [ ] Run the tests: PASS. Commit `feat(F-4): QuestionView header and feedback parts`.

## Task 3 — Answer area (MCQ list, SPR with phone keypad)

**Files:** `parts/choice_list.dart`, `parts/spr_answer_area.dart`. **Test:** `answer_area_test.dart`.

**Consumes:** `choiceLookFor`, `ChoiceTile`, `SprInput`, `SprKeypad`, `applySprKey`.

**Produces:**
- `ChoiceList({required List<ChoiceData> choices, required AnswerState answer, required QuestionViewMode mode, required bool interactive, ValueChanged<String>? onSelect, onEliminate, onRestore})`
- `SprAnswerArea({required String text, required SprInputState state, required bool useKeypad, String? correctAnswer, ValueChanged<String>? onChanged})`

`_SprAnswerAreaState` holds `_keypadVisible` and `_keyHint` only. Keypad keys call `applySprKey(widget.text, key)`, then `onChanged(edit.text)` and `setState(() => _keyHint = edit.hint)`. Typing on a hardware keyboard clears `_keyHint`.

- [ ] test-writer tests:
  1. Taps fire `onSelect` / `onEliminate` / `onRestore` with the right label. Non-interactive tiles fire nothing.
  2. With `useKeypad: true`, tapping keypad `3`, `/` and `/` produces text "3/". The second slash leaves the text unchanged, and `SprInput` shows "A fraction has only one slash." Hide removes the keypad; tapping the field shows it again.
  3. With `useKeypad: false`, no `SprKeypad` appears.
  4. Under `Revealed`, `correctAnswer` is displayed. Under `FirstMiss`, `correctAnswer` is never passed (assert on `find.byWidgetPredicate`).
- [ ] FAIL → implement → PASS. Commit `feat(F-4): QuestionView answer area`.

## Task 4 — `QuestionView` assembly and practice mode

**Files:** `question_view.dart`, `parts/question_body.dart`, `parts/question_footer.dart`. **Test:** `question_view_practice_test.dart`.

**Consumes:** everything from Tasks 1–3.

**Produces:** `QuestionView` as in *Public interfaces*, and `QuestionFooter({required Widget? leading, required Widget middle, required Widget primary, String? helper})`.

Layout:
- `LayoutBuilder` → `BookletLayout.forWidth`.
- `Column[header, Expanded(scroll body), footer]`. The footer stays pinned: 72 px with a top rule.
- The body is centred, and the column is capped at `BookletSize.questionColumn`.
- Body order: `ExerciseHeader`, stem (`MathText`), figures (`figureBuilder`, skipped when null), answer area, inline `MarginNote` (non-expanded), `HintPanel` (`FirstMiss.hintMd`), `WorkedExample` (`Correct`/`Revealed` `explanationMd`).
- At `expanded`, the note renders as a 300 px aside to the right of the column.

Practice copy:
- Mode label: "Practice".
- Progress: "Rep {rep} of {repTarget} — Homework unlocks at {repTarget}".
- Footer middle: "Rep {rep} of {repTarget}", non-interactive.
- Footer leading: "Back" (`onPrev`), shown only when non-null.

Note content:
- `FirstMiss` → miss note with `noteMd`. If `noteMd` is null and `hintMd` is non-null, the hint becomes the note body and the separate `HintPanel` is not shown (spec §2: misconception else hint).
- `Correct` → correct note (`noteMd`, or no body).
- `Revealed` → miss note with `noteMd`.

- [ ] test-writer tests, at 360 and 1280:
  1. `Idle` with nothing selected: Check is disabled. After selecting, Check fires `onCheck`.
  2. `Checking`: the button is loading and taps don't fire. Tiles are non-interactive.
  3. `FirstMiss`: the missed tile is "Incorrect", the note and hint are visible, Check is disabled until another choice is picked, and "Pick another answer" appears only at 1280.
  4. `Correct`: the green note, the worked example, and the primary "Next" firing `onNext`.
  5. `Revealed`: "Correct answer", "1st try" and "Your answer" labels, the worked example, and "Next".
  6. The note is inline at 360 and 768, and an aside at 1280. Find it via its ancestor `Row`.
  7. **Review Focus 3:** a long Arabic stem plus note plus hint at 360 / 2× text has no overflow exceptions (`tester.takeException()` is null), and the footer stays visible.
  8. `figureBuilder` is called once per path, and nothing is rendered when it is null.
- [ ] FAIL → implement → PASS. Run `flutter analyze --fatal-infos`. Commit `feat(F-4): QuestionView practice mode`.

## Task 5 — Homework mode (header status, navigator panel/sheet, submit dialog)

**Files:** `parts/homework_navigator.dart` and `parts/homework_submit_dialog.dart`, plus homework branches in `question_view.dart` / `question_body.dart`. **Test:** `question_view_homework_test.dart`.

**Produces:**
- `HomeworkNavigatorGrid({required int total, required int index, required Set<int> answered, required Set<int> marked, required int columns, ValueChanged<int>? onJumpTo})`
- `HomeworkNavigatorPanel` (wide)
- `showHomeworkNavigatorSheet(context, …)`
- `showHomeworkSubmitDialog(context, {required int total, required Set<int> answered, required VoidCallback? onSubmit, required ValueChanged<int>? onJumpTo})`

Copy:
- Mode label: "Homework · {total} questions".
- Progress: "{answered.length} of {total} answered".
- Header trailing: `SaveStatusLabel(saveStatus, onRetrySave)`.
- Footer: "Back" (`onPrev`, disabled at index 0) / "Question {index+1} of {total}" / "Next" (`onNext`, disabled on the last question).
- Wide panel: 280 px on the right, title `HomeworkMode.title`, 4 columns.
  - Legend: "Current", "Answered", "Unanswered".
  - Summary: "{a} of {t} answered · {u} unanswered. You can submit once."
  - Filled "Submit homework".
- Phone: the footer middle is a button with `expand_less` that opens the sheet.
  - The sheet uses 6 columns and a legend that adds "Marked for review" (`bookmark`).
  - It has an outlined "Submit homework" button.
- Submit dialog:
  - Title "Submit homework?"
  - Body "You can submit once. After that your answers are locked and marked."
  - When anything is unanswered: "{n} questions unanswered", chips "Q{i+1}", "Select one to go back to it."
  - Actions "Keep working" (pop) and "Submit homework" (pop + `onSubmit`).
- Homework never shows notes, hints or the worked example.

- [ ] test-writer tests:
  1. Grid cells have semantics labels "Question {n}, answered/unanswered/marked, current". Tapping a cell fires `onJumpTo(n-1)`, and on phone also closes the sheet.
  2. The panel appears at 768 and 1280 and is absent at 360. At 360, the footer button opens the sheet.
  3. **Review Focus 5:** the same widget is resized from 1280 to 360. The panel is gone, the sheet button works, and `onJumpTo` still fires.
  4. Submit → dialog with chips for the unanswered indices. A chip pops and calls `onJumpTo`. "Keep working" calls nothing. Confirm calls `onSubmit` once.
  5. The Prev/Next disabled bounds at the first and last index.
  6. Each `SaveStatus` renders, and Retry fires `onRetrySave`.
- [ ] FAIL → implement → PASS. Commit `feat(F-4): QuestionView homework mode`.

## Task 6 — Keyboard shortcuts

**File:** `parts/question_shortcuts.dart`, wrapping the body in `question_view.dart`. **Test:** `question_shortcuts_test.dart`.

**Produces:** `QuestionShortcuts({required Widget child, required List<String> labels, required bool choicesInteractive, ValueChanged<String>? onSelect, onEliminate, VoidCallback? onMark, onPrev, onNext})`.

- Use `Shortcuts` + `Actions` with intents `_SelectChoiceIntent(i)`, `_EliminateChoiceIntent(i)`, `_MarkIntent`, `_PrevIntent` and `_NextIntent`.
- Bindings: `SingleActivator(LogicalKeyboardKey.keyA)` … `keyD`; Shift+letter eliminates; `M`; `arrowLeft` / `arrowRight`.
- Each action's `isEnabled` returns false when:
  - its callback is null;
  - the choice index is ≥ `labels.length`;
  - (select/eliminate only) `!choicesInteractive`.
- The shortcuts must not fire while an `EditableText` has focus. Wrap `SprInput` in `Shortcuts(shortcuts: {}, …)` / `DoNothingAndStopPropagationTextIntent` so letters and arrows reach the field.

- [ ] test-writer tests:
  1. A / B, Shift+C, M, ← / → fire the right callback with the right label.
  2. **Review Focus 1:** with SPR focused, typing `a` and pressing ← fires nothing.
  3. **Review Focus 2:** shortcuts under `Checking` / `Revealed` do not select, and `D` on a 3-choice question does nothing.
  4. `M` does nothing when `onMark` is null.
- [ ] FAIL → implement → PASS. Commit `feat(F-4): QuestionView keyboard shortcuts`.

## Task 7 — Goldens, verification, status

**Files:**
- `test/goldens/full_viewport_harness.dart`: `expectViewportGolden(tester, {name, width, height, child, textScale})`. Extract it from `app_shell_golden_test.dart` and make that test use it.
- `test/goldens/question_view/question_view_golden_test.dart` and its baselines.
- `test/goldens/README.md` (count + scope).
- `docs/STATUS.md`.

- [ ] Golden sheet, all light, 360×800 and 1280×800 full viewport:
  - `qv_practice_idle`, `qv_practice_first_miss`, `qv_practice_correct`, `qv_practice_revealed` (Arabic in `explanationMd`), `qv_homework` (MCQ, saved, 17/20 answered).
  - Plus `qv_practice_first_miss_360_text2x`.
  - That is 11 images. Use the design copy from the extraction: Rep 7 of 10; the note texts from miss1, miss2 and correct.
- [ ] The first run FAILs (no baselines). Fix any layout errors, generate baselines on Windows with `flutter test test/goldens --update-goldens --tags golden`, and open every PNG against the export. The existing shell goldens must stay byte-identical after the harness extraction.
- [ ] Run from `apps/client/`:

  ```powershell
  dart format --output=none --set-exit-if-changed .
  flutter analyze --fatal-infos
  flutter test --exclude-tags golden
  flutter test test/goldens --tags golden
  git diff --check
  ```
- [ ] Run `/flutter-code-quality:review-gate`, then `/flutter-code-review`, then the `code-reviewer` agent. Fix findings with regression tests.
- [ ] `docs/STATUS.md`: row → PR 1 in review. Then `git-expert` handles commit/push/PR `feat(F-4): QuestionView practice + homework` (CI green).

## Verification (end-to-end)

- Every test command above is clean, and the goldens pass on Windows.
- The widget has no consumer route yet (the gallery is its own PR after PR 2), so verification is through widget tests at 360/768/1280 plus golden images inspected by eye against `QuestionView Practice.dc.html` P1–P3 and `QuestionView Homework Quiz Review.dc.html`.
- Rule-1 check: the Task 1 contract test passes, and `grep -rn "explanation\|misconception" lib/shared/widgets/question_view/question_data.dart` finds nothing.
