# 08 — Exam Engine Spec (Bluebook-style Simulator)

> Goal: a student who has done our mocks should feel *nothing new* on test day.
> Verify all format numbers against the current College Board test specifications before Phase 3 —
> the format can change.

## 1. Digital SAT Math format we simulate

| Item | Value |
|------|-------|
| Modules | 2, adaptive (Module 2 easier or harder based on Module 1) |
| Questions | 22 per module, 44 total (official test includes a few unscored pretest items; our mocks score all) |
| Time | 35 min per module, no pause; short transition screen between modules |
| Types | ~75% MCQ (4 choices), ~25% Student-Produced Response (SPR) |
| Calculator | Desmos graphing calculator available for every question |
| Score | Section score 200–800 |

Domain mix per full test (approx., verify): Algebra ~35% · Advanced Math ~35% ·
Problem-Solving & Data Analysis ~15% · Geometry & Trigonometry ~15%.

## 2. Mock lifecycle

```
mock_templates (blueprint)  ──assemble-mock──▶  mock_forms per set_no:
      form k = { M1, M2E (easier), M2H (harder) }       ← built once, reviewed by teacher
Student starts mock → pick lowest form_no in student's set_no not yet taken
   → attempt(kind=mock_module, module 1)  → submit → route → attempt(module 2: M2E | M2H)
   → mock_results (raw scores, route, estimated range, domain breakdown) → drill set
```

- Forms are **pre-assembled and frozen** (not random per student) so the teacher can review them
  and so score estimates are comparable across students.
- `set_no` ties to the enrollment's `mock_set_no`: renewal = new set the student hasn't seen (PAY-08).
- A question used in a form is excluded from all other forms in the same template (no overlap).

## 3. Blueprint (JSON in `mock_templates.blueprint`)

```json
{
  "modules": {
    "M1":  {"count": 22, "time_s": 2100, "difficulty": {"E": 7, "M": 9, "H": 6}},
    "M2E": {"count": 22, "time_s": 2100, "difficulty": {"E": 10, "M": 9, "H": 3}},
    "M2H": {"count": 22, "time_s": 2100, "difficulty": {"E": 3, "M": 9, "H": 10}}
  },
  "domains": {"Algebra": 0.35, "Advanced Math": 0.35, "PSDA": 0.15, "Geometry & Trig": 0.15},
  "spr_ratio": 0.25,
  "routing": {"threshold_correct_m1": 14},
  "ordering": "difficulty_ascending_within_module"
}
```
Numbers are starting values — the teacher can tune them in T-14.
**Bank size check:** one form = 66 questions → 10 forms ≈ 660 `mock_reserve` questions per set.

## 4. Exam screen (S-29) — feature checklist

Layout (laptop): top bar (section/module name, timer, tools) · question area · bottom bar
(question X of 22 navigator, Back/Next).

- [ ] Countdown timer with **Hide/Show**; 5-minute warning; auto-submit at 0.
- [ ] Question navigator popup: answered / unanswered / marked states; jump to any question.
- [ ] **Mark for Review** flag per question.
- [ ] **Answer eliminator** (strike-through choices) per question, persisted.
- [ ] SPR input box with live **"Answer Preview"** rendering (fraction display) and validation hints.
- [ ] **Reference sheet** (formulas) — our own rendering of standard formulas (no copied artwork).
- [ ] **Desmos graphing calculator** panel, draggable/resizable on laptop, full-screen sheet on phone; state persists per module, reset between mocks.
- [ ] Review page at end of module before submit.
- [ ] No back-navigation into Module 1 after it's submitted.
- [ ] Autosave every answer; resume after reconnect with **server-side** remaining time (deadline stored at start).
- [ ] Blocks: AI tutor, notes, practice and other app navigation hidden during an active module.
- [ ] Phone: allowed with a warning banner recommending laptop/tablet.
- [ ] Our own visual design — do not copy College Board branding/logos.

## 5. Routing & scoring

**Routing:** Module 1 correct ≥ `threshold_correct_m1` → M2H, else M2E.

**Score estimate (v1 heuristic):**
```
raw_total = correct_m1 + correct_m2
scale table chosen by route (two lookup tables: M2E caps lower, M2H reaches 800)
est_mid = table[route][raw_total]
range   = est_mid ± 30   (round to nearest 10, clamp 200–800)
```
- Tables stored in `settings` (`sat_scale_easy`, `sat_scale_hard`), editable by the teacher.
- Show as a **range** with the note "estimate — official scoring uses a different, unpublished model".
- Calibration (P1): when students log official scores (MCK-06), compare and adjust tables.

**Report contents (MCK-04):** estimated range · correct per module · per-domain and per-skill accuracy ·
time per question chart with "spent > 2× average" flags · list of marked questions · wrong answers
with explanations · CTA "Start drill set" (10–15 practice questions on the 3 weakest skills).

## 6. SPR answer normalisation (GRD-02)

Input rules shown to students (mirror the official directions):
- Max 5 characters for positive answers, 6 for negative (minus counts); `.` and `/` count as characters.
- Fractions and decimals allowed; fractions need not be reduced.
- **Mixed numbers not allowed** (`3 1/2` is invalid; enter `7/2` or `3.5`).
- Repeating/long decimals must fill the box (truncate or round at the last allowed position).
- No `%`, `$`, commas or units.

Grader algorithm:
```
1. Trim; reject if contains space between digits, letters, %, $, ','  → invalid (counts wrong)
2. Enforce length limit → invalid if too long
3. Parse: integer | decimal (".5" allowed) | fraction a/b (b ≠ 0) → rational/decimal value v
4. For each accepted key value k:
     if k is exact rational:   correct if v == k  OR  v is a valid truncation/rounding of k
                               filling the available characters (e.g. 2/3 → .6666, .6667, 0.666, 0.667)
     if key has tolerance t:   correct if |v - k| ≤ t
5. Multiple accepted keys (questions with several valid answers): any match is correct
```
Write unit tests for: `1/2`, `.5`, `0.5`, `2/4`, `-3/4`, `-.75`, `2/3` vs `.666`/`.6666`/`.6667`/`.67`,
`3 1/2`, `10000` (5 chars ok), `100000` (too long).

## 7. EST mock (MCK-07)
- Separate `mock_templates` row with `adaptive=false`, its own blueprint (sections, counts, timing,
  calculator policy) — **format details to be supplied by the teacher** (open question Q-08).
- Same engine and screen components; tools enabled/disabled per template (`tools: ["desmos","reference"]`).
- Teacher's existing EST exams can be imported as fixed forms (he holds rights to them — confirm).

## 8. Official practice tests
We do **not** host College Board practice tests (copyright). Instead (MCK-06):
schedule "Official Practice Test N in Bluebook" items in the mock plan and let students log their score.
