# Claude Design coverage — F-4 / row 6

Source: Claude Design project "Design system foundations and components", exported 2026-10-13 to `docs/design/claude-design-export/`.
Brief: `2026-10-08-claude-design-brief.md` (12 sessions).

## Coverage by session

| Session | Screens / parts | Files | Status |
|---|---|---|---|
| 1 | Brand, tokens, components, app shell | `Foundations`, `Components`, `Components Dark`, `App Shell` | Present |
| 2 | QuestionView practice + mock | `QuestionView`, `QuestionView Practice`, `QuestionView Mock`, `QuestionView Overview` | Present |
| 3 | QuestionView homework, quiz, review, states | `QuestionView Homework Quiz Review`, `QuestionView States` | Present |
| 4 | S-12, S-13, S-14, S-15, S-18, S-23 | `Learning Path` (+ Overview) | Present |
| 5 | S-16, S-17, S-25, S-26 | `Content and Help` (+ Overview) | Present |
| 6 | S-21, S-24 | `Results and Skills` (+ Overview) | Present |
| 7 | S-27, S-28, S-30, S-31 | `Mock Phase` (+ Overview) | Present |
| 8 | S-03, S-10, S-11, S-32, S-33, S-34, S-35 | `Account and Commerce` (+ Overview) | Present |
| 9 | S-01, S-02, S-04 | `Public Pages` (+ Overview) | Present |
| 10 | T-01, T-09, T-10, T-11, T-12 | `Teacher Area A` (+ Overview) | Present |
| 11 | T-02 to T-08 | `Teacher Area B` (+ Overview) | Present |
| 12 | T-13 to T-17 | `Teacher Area C` (+ Overview) | Present |

Every `S-xx` / `T-xx` heading in the brief was found in the export (checked by text search).

## Open items

- [ ] **Pass mark mismatch.** `Teacher Area A` shows quiz pass mark 70% ("Locked · needs 4.3 quiz at 70%", "Quiz 4.3 below 70%"). Spec says 75 (`docs/06` settings `pass_mark`, `docs/07` §2, PRD LRN-02). Implementation reads `settings.pass_mark`; fix the design copy or ignore the sample value.
- [ ] **Device limit 2** in design matches `settings.device_limit = 2` (PRD AUTH-04). No action.
- [ ] **Stuck / inactive rules** ("7+ days or 3 failed quizzes", "no lesson, homework or quiz activity") are design assumptions. Confirm with the teacher or PRD ANL-06 before implementing.
- [x] **States check (done).** Each `* Overview.dc.html` lists its screen/state rows as data (`ROWS`). Checked against the brief deliverables: all required states exist (loading/empty/error/confirm where the brief asks; QuestionView practice empty lives in `QuestionView Practice`, not its Overview). Widths: QuestionView 360/768/1280, Public Pages 360 + 1440/1280, Teacher areas 1280 (+1440 where asked).
- [ ] **Dark theme** is shown for `Components Dark`, `Foundations`, and S-34 only; no other screen has a dark variant. Decide at implementation: tokens carry dark, screens are not mocked in dark.
- [ ] **Not verified by eye:** pixel quality of any screen. Do a quick visual pass in Claude Design (or open the exported `*.dc.html`) before building each feature.
