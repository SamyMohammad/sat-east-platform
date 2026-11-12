# SAT mock exam — design

> Date: 2026-11-12 · Requirements: MCK-01, MCK-02, MCK-03, MCK-04 (basic), MCK-09 (changed), AI-03.
> Base spec: `docs/08-exam-engine-spec.md` §1–§5. Roadmap: `2026-11-12-pre-beta-roadmap-design.md`.
> Lines marked **(owner)** were decided by the owner. Lines marked **(router)** are the
> router's calls and can be overturned in review.

## Intent

A student who has done our mocks should feel nothing new on test day. The mock is the last
big student feature the owner wants in place before the closed beta opens. It ships on web.

## Goals

- A full Digital SAT Math simulation: two adaptive modules, 22 questions and 35 minutes each.
- Forms are built once by the server from a blueprint, reviewed by the teacher, then frozen,
  so every student with the same form gets the same exam and scores are comparable.
- A basic score report the student can learn from.

## Non-goals

EST mock (MCK-07) · diagnostic mock (MCK-05) · score history and official scores (MCK-06) ·
schedule (MCK-08) · drill set, time-per-question chart, marked-question list (rest of MCK-04) ·
blueprint editor · Desmos panel (on hold, see roadmap) · Android / iOS.

## Anti-goals

- No key, explanation or correctness signal reaches the client before a module is submitted
  (CLAUDE.md rule 1). Module 1 results stay hidden until the whole mock is finished, or the
  student could infer the route.
- The client never decides the route, the score, the remaining time or whether a form is unlocked.
- A published form never changes.
- No magic numbers: blueprint values, scale tables and unlock thresholds come from data.

## What exists today

- Tables `mock_templates`, `mock_forms` (one row per module, `question_ids uuid[]`) and
  `mock_results` (`f2_schema.sql`); RLS on, only "student selects own `mock_results`".
- `attempts.kind` has `mock_module`; `attempts` has `mock_attempt_group`, `mock_form_id`,
  `module_no`, `time_limit_s`. `enrollments.mock_set_no` exists.
- `questions.pool` has `mock_reserve`; import and editor can set it. `skills.domain` is free text.
- Quiz RPCs `start_quiz`, `save_answer`, `submit_attempt` and the quiz `QuestionView` mode
  (exam bar, timer with Hide/Show, 5-minute warning, navigator, mark for review).
- Shared attempt report (`get_attempt_review`) and the persistent answer outbox (#84).
- Client: `/mock-exams` is a placeholder screen. No mock RPCs, no settings keys, no demo
  `mock_reserve` questions.

## Part 1 — Assembly (server)

**Template.** One SAT template per course, seeded with the blueprint from `docs/08` §3.
Read-only for the teacher in the beta; changes go through a migration **(owner)**.

**Domains.** The four blueprint domains are Algebra, Advanced Math, PSDA, Geometry & Trig.
A question's domain comes from the `domain` of its linked skills. A question whose skills
do not resolve to exactly one of the four is not eligible **(router)**. There is no global
constraint on `skills.domain` (EST and test fixtures use other values): a skill counts
toward a blueprint domain only when its `domain` equals one of the names in that template's
blueprint, and the shortage report lists the `mock_reserve` questions that match none.

**Eligible question:** `pool = mock_reserve`, `status = published`, belongs to the
template's course, has one domain, and is not in any other form (draft or published) of the
same template.

**Assemble.** A teacher-only RPC builds one form (M1, M2E, M2H = 66 questions) for a given
`set_no`, with the next free `form_no`:
- per module: the blueprint's E/M/H counts;
- across each module: domain shares and the SPR ratio, rounded so the counts sum to 22
  (the rounding rule is the builder's, but it must be deterministic and tested);
- order inside a module: difficulty ascending;
- selection among equally valid candidates is random.

**Shortage.** If the bank cannot satisfy the blueprint, nothing is created. The RPC returns a
shortage report: how many questions are missing per module, domain, difficulty and type, and
how many `mock_reserve` questions were skipped for having no single domain **(owner)**.

**Draft and publish.** A new form is a draft. `mock_forms` gains a status (draft / published)
and a published timestamp, the same for all three module rows of a form **(router)**.
- Swap: the teacher replaces one question with another eligible question of the same domain,
  difficulty and type. The server validates; the module is re-ordered.
- Delete draft: the form is removed and its questions are free again.
- Publish: the form is frozen. No swap, no delete. If a question in a published form is later
  retired or edited, the form keeps pointing at it; key fixes are handled by the regrade
  project (lane B), not here.

**Demo data.** The staging demo seed gains at least 66 `mock_reserve` questions shaped to
fill one form, plus the skills/domains they need. Still seeded by CI, never by a migration.

## Part 2 — Teacher screen (T-14, reduced)

In the teacher area, a "Mock exams" page:
- the template's blueprint, read-only;
- bank readiness: eligible question counts against what one more form needs;
- list of forms per set with status;
- "Assemble form" → either a draft or the shortage report;
- draft view: three modules, each question previewed with the shared `QuestionView`
  (teacher sees key and explanation), swap, delete draft, publish (with a confirm).

Layout and copy are the builder's, following `DESIGN.md`.

## Part 3 — Taking the mock (student)

**Unlock (owner).** One setting holds a list of numbers, for example `[3, 6, 10]`. Form *k* in
the student's set unlocks when the student has passed that many topics in the course. Forms
beyond the end of the list use the last number **(router)**. "Form *k*" is the k-th
**published** form of the set ordered by `form_no`, so gaps left by deleted drafts do not
matter **(router)**. The teacher edits the list on the
existing settings screen. This replaces the MCK-09 rule in the PRD; the PRD is updated in
the same PR.

**Which form.** The lowest published `form_no` in the student's `mock_set_no` that the
student has not started. One attempt per form **(router)**. Needs an active enrolment.
A student cannot start another form while one is unfinished; because module 2 always starts
by itself (below), a started mock always ends with a result, also when the enrolment
expires or renews in the middle **(router)**.

**Mock hub (S-27) and pre-exam (S-28).** The hub lists the student's forms: locked (with what
is needed), available, in progress (resume), finished (open report). The pre-exam screen
states the rules: 2 modules, 35 minutes each, the timer does not pause, no going back to
module 1. On a phone it shows a banner recommending a laptop or tablet; the student may
continue.

**Engine.** All on the server:
- Starting creates the module-1 attempt with a deadline of start + the blueprint's `time_s`.
  The deadline keeps running if the student leaves **(router)**. Resume returns the remaining
  time from the server.
- Answers autosave through the existing save path and the persistent outbox, including mark
  for review and eliminated choices.
- Submitting module 1 (by the student or by the deadline) grades it, picks the route
  (`correct ≥ routing.threshold_correct_m1` → M2H, else M2E) and returns only what is needed
  to continue. The student sees a transition screen with a short countdown from a setting
  (starting value about two minutes). They can start module 2 early; if the countdown ends
  first, module 2's clock starts on the server by itself and the module is submitted at its
  deadline with whatever was saved **(owner)**.
- A module that passes its deadline is submitted by the server with whatever was saved.
  The existing expiry cron is extended to mock modules, and every mock RPC (start, resume,
  save, hub) also finishes an overdue module on the spot, so routing never waits for the
  cron **(router)**. `save_grace_s` applies as it does for quizzes.
- Submitting module 2 writes `mock_results`: route, raw scores, estimated range, domain
  breakdown.
- Nothing from module 1 is visible before module 2 is submitted: the `attempt_answers` read
  policy and `get_attempt_review` both refuse a mock module whose mock is unfinished, and
  skill mastery for both modules is applied once, when module 2 is submitted **(router)**.
- A private helper answers "does this student have an active exam?" (a quiz in progress, a
  mock module in progress, or the gap between mock modules). The mock ships it; lane B's
  `ai-tutor` function calls it for AI-03 **(router)**.

**Score (docs/08 §5).** `raw_total = correct_m1 + correct_m2`; the scale table is chosen by
route; range = table value ± 30, rounded to 10, clamped to 200–800. The two tables are new
settings (`sat_scale_easy`, `sat_scale_hard`), teacher-editable, seeded with starting values
the builder proposes and the owner approves in the plan review. The ± 30 is a setting too.
In the beta the tables are edited as JSON with server-side validation (45 entries, raw 0–44,
values 200–800, non-decreasing); if the existing settings screen cannot edit JSON values,
they change by migration and a table editor comes after the beta **(router)**.

**Exam screen (S-29).** The mock is a fourth `QuestionView` mode built on the quiz mode, not a
second widget (CLAUDE.md rule 6). Added on top of quiz:
- answer eliminator (strike-through per choice, persisted);
- reference sheet of standard formulas, our own rendering;
- end-of-module review page before submit;
- module transition screen; no way back into module 1;
- app navigation, notes and Ask AI hidden while a module is active and during the gap
  between modules.
- The exam bar keeps a slot for the calculator; it stays hidden until the Desmos decision.

Our own visual design; nothing copied from College Board.

## Part 4 — Report (S-31, basic) (owner)

After module 2: estimated range with the note "estimate — official scoring uses a different,
unpublished model"; route taken; correct per module; accuracy per domain and per skill;
every question with the student's answer, the key and the explanation, wrong ones first.
It reuses the shared attempt report. Mock answers feed skill mastery with the existing
`mock` weight. Ask AI entry points appear here when lane B lands.

## Build order

Four plans, four PRs, in this order: (1) assembly server + demo seed, (2) teacher screen,
(3) engine RPCs + exam screen, (4) report. Part 3 may split into server and client PRs if
the plan gets large. Every new SQL file starts from `supabase/templates/` and ships pgTAP
tests; every RPC gets an explicit grant; error codes are added to `docs/07` §9.

## Constraints

- CLAUDE.md non-negotiables, especially rules 1, 2, 3, 5, 6, 9, 10.
- Before part 3: check the format numbers (22 questions, 35 minutes, domain mix) against the
  current College Board specification and record the source in `docs/08`.
- Web at 360 px and 1280 px.

## Left to the builder

RPC names and signatures, error codes, exact settings key names, rounding rule for
domain/SPR counts, table changes beyond the form status, Cubit/state shape, screen layout
and copy, PR split inside each part.

## Docs to update with the build

`docs/02-prd.md` (MCK-09), `docs/06-data-model.md` (form status; `attempts(kind=mock)` →
`mock_module`), `docs/07` (mock RPCs, error codes), `docs/08` (verified format, unlock rule),
`docs/STATUS.md`.
