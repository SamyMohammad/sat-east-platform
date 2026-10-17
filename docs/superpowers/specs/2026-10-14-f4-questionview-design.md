# F-4 — QuestionView (practice, homework, quiz) — design

Status: approved 2026-10-14. Parent spec: [`2026-10-13-f4-design-system-questionview-design.md`](2026-10-13-f4-design-system-questionview-design.md) §3. Tier **L** (`docs/15` §2): one shared widget used by four features.
Rules in play: CLAUDE.md rule 1 (no answer keys on client before submission), 6 (one `QuestionView`), 8 (mixed Arabic/English), B.1–B.3 (stateless presentation, domain purity).
Design source: `docs/design/claude-design-export/QuestionView.dc.html`, `QuestionView Practice.dc.html`, `QuestionView Homework Quiz Review.dc.html`, `QuestionView States.dc.html`.

## Goal
Ship the shared `QuestionView` in the modes the Phase 1 vertical slice needs (practice → quiz → unlock), built on the merged components (`ChoiceTile`, `SprInput`, `SprKeypad`, feedback widgets, `FocusModeScaffold`).

## Scope and phasing (decided 2026-10-14)
| When | Modes | PR |
|------|-------|----|
| Now | Core + **practice** + **homework** | QuestionView PR 1 |
| Now | **quiz** (exam bar, timer, navigator, submit and time-up dialogs) | QuestionView PR 2 |
| With the results/review work | **review** (time bar, margin note, mistake-notebook action) | later |
| Phase 3 (mock exam engine) | **mock** (review-before-submit page, 5-minute warning, exit confirm), built on the quiz exam bar | later |

Out: the gallery page (own PR after PR 2), any Cubit, repository or RPC. Mock waits because Desmos and adaptive modules can still change its chrome.

## 1. Files and public API (`lib/shared/widgets/question_view/`)
```
question_view.dart        QuestionView — stateless; renders by mode and breakpoint
question_data.dart        QuestionData {id, stemMd, imagePaths, kind}
                          sealed QuestionKind: McqKind(choices: List<ChoiceData{label, md}>) | SprKind
                          — no key, explanation or misconception field
question_view_mode.dart   sealed QuestionViewMode:
                            PracticeMode(feedback: PracticeFeedback)
                            HomeworkMode(index, total, saveStatus, answeredIds, markedIds)
                            QuizMode(index, total, remaining: Duration, answeredIds, markedIds)   ← PR 2
answer_state.dart         AnswerState {selected, eliminated, marked, sprText}
practice_feedback.dart    sealed PracticeFeedback:
                            Idle | Checking
                            | FirstMiss(noteMd?, hintMd?)
                            | Correct(explanationMd?)
                            | Revealed(key: AnswerKey, explanationMd?)
parts/                    stem column, margin note, light header, footer,
                          navigator (side panel / sheet; popover in PR 2), exam bar (PR 2)
```
- Callbacks: `onSelect`, `onEliminate`, `onSprChanged`, `onCheck`, `onNext`, `onPrev`, `onMark`, `onJumpTo`, `onSubmit`. All nullable where a mode does not use them.
- No business logic. Feature Cubits own state, retries, saving and timers, and pass plain values in.
- `AnswerKey` exists only inside `Revealed` (and later review), i.e. after the server returned it.
- Time: `QuizMode.remaining` is computed by the Cubit from an injected clock; the widget never starts a timer.

## 2. Practice (PR 1)
- States follow the export: `empty` → `Checking` → `FirstMiss` (red-pen margin note + hint open, student tries again) → `Revealed` on the second miss, or `Correct` at any try.
- Margin note text: the misconception for the chosen choice when the server sends one, else the hint.
- Footer: Check while unanswered, Next after `Correct` / `Revealed`.

## 3. Homework (PR 1)
- Light header with position (`index / total`) and save status (saving / saved / offline).
- Navigator: side panel at wide widths, bottom sheet on phone; shows answered and marked.
- Answers editable until the single Submit (PRC-02). No hints, no feedback.

## 4. Quiz (PR 2)
- Exam bar with remaining time; navigator popover (wide) or sheet (phone); submit confirmation dialog; time-up dialog. No feedback (quiz shows results after submission).

## 5. Layout, input and accessibility
- Breakpoints: reuse `BookletLayout.forWidth` — `compact` (≤ 600 px) is phone, `medium`/`expanded` are wide; stem column max 720 (`BookletSize.questionColumn`).
- `SprKeypad` on phone for SPR; hardware keyboard elsewhere.
- Shortcuts (`Shortcuts`/`Actions`): `A`–`D` select, `Shift`+`A`–`D` eliminate, `M` mark, `←`/`→` previous/next.
- Stem and explanation through `MathText` (mixed RTL/LTR, rule 8).

## 6. API change — `check_practice_answer` (docs/07 §2)
Superseded by `2026-10-17-p1-practice-design.md` §1.4: `reveal` dropped; server reveals on wrong try 2.

`check_practice_answer(question_id, answer, time_ms, reveal bool default false)`:
- correct → `is_correct = true`, `key`, `explanation`.
- wrong and `reveal = false` → `is_correct = false`, `hint`, `misconception` for the chosen answer (when present). **No key, no explanation.**
- wrong and `reveal = true` → `is_correct = false`, `key`, `explanation`.

The client sends `reveal = true` on the second miss. Sending it early gains nothing the student would not see after two misses; practice questions come from the practice pool only. Implemented with the practice story (PRC-01), not in this PR.

## 7. Testing
- Widget: per mode, the right chrome renders and each callback fires; each practice state renders its feedback; homework navigator on phone (sheet) and wide (panel); shortcuts dispatch the right callback.
- Contract: `QuestionData` and `QuestionKind` expose no key, explanation or misconception field.
- Golden (tag `golden`, Windows baselines): practice `empty`, `FirstMiss`, `Revealed`, `Correct` and homework at 360 and 1280, light; one 2× text variant. Quiz goldens in PR 2.
- Deterministic: no real timers or network.

## Done when
PR 1: practice + homework as above, `dart format`, `flutter analyze --fatal-infos`, `flutter test` clean, goldens pass on Windows, CI green. PR 2: quiz as above, same gates.
