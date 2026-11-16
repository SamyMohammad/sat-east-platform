# 08 — Exam Engine Spec (Bluebook-style Simulator)

> Goal: a student who has done our mocks should feel *nothing new* on test day.
> Format numbers below were verified against the College Board pages listed in §1 on 2026-11-13.
> Re-check them when College Board announces a change; they can change.

## 1. Digital SAT Math format we simulate

| Item | Value |
|------|-------|
| Modules | 2, multistage adaptive (Module 2 easier or harder based on Module 1) |
| Questions | 22 per module, 44 total. Officially 20 operational (scored) + 2 pretest (unscored) per module; **our mocks score all 22** (raw 0–44) |
| Time | 35 min per module; no break between the two Math modules; short transition screen |
| Types | ~75% multiple choice (4 choices), ~25% Student-Produced Response (SPR) |
| Calculator | Allowed on every question. Bluebook has a built-in Desmos graphing calculator (or a scientific one); students may instead bring their own approved non-CAS calculator. A reference sheet of formulas is provided |
| Score | Section score 200–800 from an IRT model (College Board does not publish the table) |

Domains (official share of the ~40 scored questions): Algebra 35% (13–15) · Advanced Math 35% (13–15) ·
Problem-Solving & Data Analysis 15% (5–7) · Geometry & Trigonometry 15% (5–7).

**Sources (checked 2026-11-13):**
- https://satsuite.collegeboard.org/k12-educators/about/alignment/math — 20 operational + 2 pretest per module, 44 total.
- https://satsuite.collegeboard.org/sat/whats-on-the-test/structure — two 35-minute Math modules, no break between them, module 2 easier or harder.
- https://satsuite.collegeboard.org/media/pdf/assessment-framework-for-digital-sat-suite.pdf — domain shares, 75% MCQ / 25% SPR, multistage testing, IRT scaling 200–800, reference sheet, calculator rules.

**Our decisions where the official material is silent or differs:**
- All 22 questions of a module are scored (no hidden pretest items), so raw score is 0–44.
- Per module, domains split 8 / 8 / 3 / 3 (Algebra / Advanced Math / PSDA / Geometry & Trig), which is the 35/35/15/15 mix rounded to whole questions (blueprint, §3).
- The routing threshold (`threshold_correct_m1`) and the two scale tables (§5) are **our estimate**, not College Board numbers; the report says so.

## 2. Mock lifecycle

```
mock_templates (blueprint)  ──teacher_assemble_mock_form──▶  mock_forms per set_no (draft)
      form k = { M1, M2E (easier), M2H (harder) }       ← built once, reviewed by teacher
   draft ──swap / delete──▶ draft ──teacher_publish_mock_form──▶ published (frozen)
Student starts mock → pick lowest form_no in student's set_no not yet taken
   → attempt(kind=mock_module, module 1)  → submit → route → attempt(module 2: M2E | M2H)
   → mock_results (raw scores, route, estimated range, domain breakdown) → drill set
```

### 2.1 Student flow (server engine, MCK-03 part 3a)

- **Unlock (MCK-09).** The student's k-th playable form (k = 1, 2, …) needs `settings.mock_unlock_topics[min(k, length)]`
  passed topics (a topic is passed when its quiz is passed). Seed `[3, 6, 10]`: form 1 after 3 topics, form 2 after 6,
  form 3 and later after 10. `k` counts only **published** forms of the student's `mock_set_no` that have all three
  modules published, ordered by `form_no`, so drafts and gaps in `form_no` do not shift it. `get_mock_hub` shows each form
  as `locked | available | in_progress | finished` with its `need`.
- **Start.** `start_mock` resumes an unfinished mock if there is one (even if the enrolment expired meanwhile: a started
  mock always ends); otherwise it starts the lowest unstarted form that is unlocked. Nothing unlocked: `mock_locked`;
  every form taken: `mock_none_available`. One M1 per student and form. Module 1 gets `time_limit_s = blueprint.modules.M1.time_s`;
  its questions are written to `question_exposure`.
- **Timing.** The deadline is stored (`started_at + time_limit_s`); saves are accepted until deadline + `save_grace_s`.
  A module past deadline + grace is finished **at its deadline** by the next mock RPC of that student or by the
  every-minute cron (`expire_overdue_attempts`), whichever comes first. Unanswered questions count as wrong.
- **Gap.** Submitting M1 sets the route (`correct_m1 >= threshold_correct_m1` → M2H, else M2E) and
  `meta.gap_until = submit time + settings.mock_gap_s` (seed 120 s). The student can start M2 early with
  `start_mock_module2` (M2 starts now); otherwise M2 starts **automatically at `gap_until`** (so its clock is already
  running when the student comes back) and is auto-finished if the whole time has passed.
- **Nothing before M2 ends.** Until module 2 is finished the student receives no route, no score, no keys and no
  module-1 answers: `submit_attempt` on a module returns only `{stage, …}`, and the `attempts` / `attempt_answers` rows of
  a mock stay hidden by RLS until the group has a `mock_results` row (06 §Mocks). `get_attempt_review` for mock modules
  arrives with the report (part 4).
- **Mastery.** Mock answers feed `apply_mastery` (weight `mock`) once, when module 2 finishes — not per module.
- **Active exam.** `private.has_active_exam(uid)` is true during a quiz, a mock module or the gap; the AI tutor (AI-03)
  uses it to refuse during an exam.

- Forms are **pre-assembled and frozen** (not random per student) so the teacher can review them
  and so score estimates are comparable across students.
- `set_no` ties to the enrollment's `mock_set_no`: renewal = new set the student hasn't seen (PAY-08).
- A question used in a form is excluded from all other forms in the same template (no overlap).
- A new form is a **draft**: the teacher can swap a question for another eligible one of the same
  cell (domain, difficulty, type) or delete the draft. **Publish** re-checks every question, then
  freezes the form (no swap, no delete). Only published forms reach students.

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

The SAT blueprint is the `settings` key `mock_blueprint_sat`; the course's template copies it on
first use and assembly always reads the template's copy. Changes go through a migration.

**Slot rule.** Assembly turns a blueprint into a fixed list of slots per module (a slot = one cell:
difficulty, domain, type), deterministic so it can be tested. For a module with `count = N` and
difficulty counts `E, M, H`:

1. **Difficulty:** slots `1..E` are E, the next `M` are M, the rest H (difficulty ascending).
2. **Domain counts:** `n_d = floor(share_d × N)`; the remaining `N − Σ n_d` go one each to the domains
   with the largest fractional part, ties by domain name ascending.
3. **Domain of slot i** (from 1): the domain with the largest `n_d × i / N − already_assigned_d`,
   ties by domain name ascending.
4. **Type:** `s = round(N × spr_ratio)` (half up); slot i is `spr` when
   `floor(i × s / N) > floor((i − 1) × s / N)`, else `mcq`.

Assembly fills each slot with a random unused eligible question of its cell. Eligible: `mock_reserve`,
published, topic in the template's course, skills resolving to exactly one domain that is a
blueprint key, and in no form of the same template. A blueprint whose counts or shares do not add up
is refused with `internal`.

With the seeded blueprint every module has 8 Advanced Math, 8 Algebra, 3 Geometry & Trig and 3 PSDA
questions, with SPR at slots 4, 8, 11, 15, 19 and 22. One form (M1 + M2E + M2H, 66 questions) needs:

| Domain | Difficulty | Type | Per form |
|--------|-----------|------|---------:|
| Advanced Math | E | mcq | 8 |
| Advanced Math | M | mcq | 7 |
| Advanced Math | M | spr | 2 |
| Advanced Math | H | mcq | 6 |
| Advanced Math | H | spr | 1 |
| Algebra | E | mcq | 6 |
| Algebra | E | spr | 1 |
| Algebra | M | mcq | 7 |
| Algebra | M | spr | 3 |
| Algebra | H | mcq | 2 |
| Algebra | H | spr | 5 |
| Geometry & Trig | E | mcq | 3 |
| Geometry & Trig | M | mcq | 1 |
| Geometry & Trig | M | spr | 3 |
| Geometry & Trig | H | mcq | 2 |
| PSDA | E | spr | 2 |
| PSDA | M | mcq | 3 |
| PSDA | M | spr | 1 |
| PSDA | H | mcq | 3 |

`teacher_mock_overview` returns this table as `need_per_form`, computed from the template's blueprint.
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
- [ ] **Calculator.** Official Bluebook offers a built-in Desmos graphing (or scientific) calculator, or the student's own approved non-CAS calculator. Our exam bar keeps a slot for it, hidden until the Desmos decision (spec Part 3). When enabled: Desmos panel, draggable/resizable on laptop, full-screen sheet on phone; state persists per module, reset between mocks.
- [ ] Review page at end of module before submit.
- [ ] No back-navigation into Module 1 after it's submitted.
- [ ] Autosave every answer; resume after reconnect with **server-side** remaining time (deadline stored at start).
- [ ] Blocks: AI tutor, notes, practice and other app navigation hidden during an active module.
- [ ] Phone: allowed with a warning banner recommending laptop/tablet.
- [ ] Our own visual design — do not copy College Board branding/logos.

## 5. Routing & scoring

**Routing:** Module 1 correct ≥ `threshold_correct_m1` → M2H, else M2E.

**Score estimate (v1 heuristic, our own model — College Board's IRT scaling is not published):**
```
raw_total = correct_m1 + correct_m2
scale table chosen by route (two lookup tables: M2E caps lower, M2H reaches 800)
est_mid = table[route][raw_total]
range   = est_mid ± 30   (round to nearest 10, clamp 200–800)
```
- Settings: `sat_scale_easy` and `sat_scale_hard` (45 integers each, raw 0–44, 200–800, non-decreasing, rounded to 10) and
  `sat_scale_margin` (30). Seeded by migration with starting values: easy rises linearly 200 → 620 over raw 0–35 and
  reaches 650 at 44; hard rises 200 → 480 over raw 0–14 and reaches 800 at 44 (hard raw below 14 is unreachable on that
  route). They change by migration in the beta (not in the teacher settings screen); `private.mock_scale_ok` validates
  a table and `private.mock_score(route, raw)` returns the range, raising `mock_settings_invalid` on a bad table.
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
Precise rules (row 4, 2026-10-07):
- Forms: integer, decimal (`1.5`, `.5`, `5.`), fraction `a/b` of integers with `b ≠ 0`; one optional
  leading `-`. Rejected: inner spaces, letters, `%`, `$`, `,`, `+`, mixed numbers, `1.5/2`.
- Fill rule: when the value is not exactly a key, it is correct only if the answer is a decimal of
  exactly the maximum length (5, or 6 with `-`) and equals the key truncated or rounded half away
  from zero at that many decimal places (`.666` for 2/3 is incorrect: 4 characters).
  Padding zeros do not count as filling: at most one `0` may precede the point (`00.67` is incorrect).
- Zero fill: a filled answer whose value is 0 is incorrect when the key is not 0 (`.0000` for `1/30000`).
- Values are exact rationals; tolerance is `|v − k| ≤ t`. Key values are not length-limited.
- A key whose `accepted` is missing, empty, or holds any non-string or unparseable value, or whose
  `tolerance` is not a number, raises `invalid_key` before grading (for every answer).
- Authoring rule: a non-terminating answer must be keyed as the exact fraction (`2/3`, not
  `0.6667`); a rounded key makes correct answers like `.6666` grade wrong.
- Only outer ASCII spaces are trimmed; tab, newline or NBSP make the input invalid.
- Implementations: `private.grade_spr` / `private.spr_parse` (server, grades) and
  `lib/core/grading/spr_answer.dart` (client, validation + Answer Preview only). Shared cases:
  `supabase/tests/fixtures/spr_cases.json`.

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
