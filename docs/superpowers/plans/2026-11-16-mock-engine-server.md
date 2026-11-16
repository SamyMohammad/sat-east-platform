# Mock exam engine — server (MCK-01, MCK-09) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## Context

Parts 1 and 2 of the SAT mock are merged (#87 assembly server, #88 teacher screen): a teacher can publish frozen forms. Students cannot take them yet. Part 3 of the spec is split in two PRs; **this plan is 3a, the server engine**: unlock rule, start, autosave, module 1 → routing → gap → module 2, expiry, score and `mock_results`. 3b (student hub, pre-exam and exam screen in Flutter) gets its own plan after this merges and is the first consumer of these RPCs.

**Goal:** A student with an unlocked published form can take a two-module adaptive mock entirely through RPCs, with the server owning time, routing and score, and nothing from module 1 visible before module 2 ends.

**Architecture:** One migration. A private table `private.mock_runs` holds one row per (student, form) with the hidden state (route, module 1 raw score, gap start). The two modules are ordinary `attempts` rows of kind `mock_module`, so the existing `save_answer` / `submit_attempt` and the answer outbox keep working. One private function, `private.mock_tick(uid)`, moves a run forward when time has passed; every mock RPC calls it first and the existing minute cron calls it too.

**Tech Stack:** Postgres (plpgsql), pgTAP, pg_cron (existing job). No client code.

**Spec:** `docs/superpowers/specs/2026-11-12-mock-sat-design.md` Part 3 ("Unlock", "Which form", "Engine", "Score"). Base: `docs/08-exam-engine-spec.md` §4–§5.

## Global Constraints

- SQL files start from `supabase/templates/`; checklist `docs/16` §2. `security definer`, `set search_path = ''`, `auth.uid()` null → `not_authenticated`, `revoke … from public, anon` + `grant … to authenticated` on public RPCs; private helpers revoked from `authenticated` too.
- **No key, explanation, `is_correct`, score or route reaches the student before module 2 is submitted** (CLAUDE.md rule 1). Module payloads have the same shape as `start_quiz`'s `questions[]` (no keys).
- Time, routing, score and unlock are decided on the server only (rule 2). No magic numbers (rule 5): every number below is a `settings` key or comes from the template blueprint.
- New table ships with RLS + a test (rule 3); it lives in `private` and is not reachable over the API.
- Errors: `raise exception '<code>'`, codes in `docs/07` §9.
- Reuse, do not copy: `private.grade_answer`, `private.apply_mastery`, `private.hit_rate_limit` with the existing `rate_start_per_min` / `rate_save_per_min` / `rate_submit_per_min`, `private.topic_states(uid, course)` (passed = `status = 'completed'`), `public.has_access`, the question-payload builder used by `start_quiz` (`20261105100000_crs06_free_preview.sql:404-494`), `private.expire_overdue_attempts` (`20261018100000_lane2a_expire_cron.sql`).
- Do not commit. Never stage `.codex/`, `.impeccable/`, `.vscode/`, `.wrangler/`, `content/`. Commit messages end with `Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>`.
- Gates: `scripts/db-up.ps1`, `supabase db reset --local` after editing the migration, `scripts/db-test.ps1` (full suite), `supabase db lint`. Demo seed must still pass (`scripts/db-seed-demo.ps1 -Check`, then reset).

## Decisions

**Owner (2026-11-16):** the unlock rule is two teacher-editable numbers, not a list: the first form needs `mock_unlock_first_topics` passed topics, each later form `mock_unlock_step_topics` more. Form *k* (the k-th **published** form of the student's set by `form_no`) needs `first + (k − 1) × step`.

**Router calls:**
1. New settings (all integers, added to `private.teacher_setting_spec()` group `Mock`): `mock_unlock_first_topics` 3 (0–50), `mock_unlock_step_topics` 3 (0–50), `mock_gap_s` 120 (0–900), `mock_warn_s` 300 (0–1800), `mock_score_margin` 30 (0–100).
2. Scale tables `sat_scale_easy`, `sat_scale_hard`: JSON arrays of 45 integers (raw 0–44), changed by migration only (`teacher_update_settings` rejects arrays). `private.mock_scale_ok(jsonb)` validates: 45 entries, each 200–800, multiple of 10, non-decreasing. **Starting values are a straight line, not calibrated** — hard: `round10(200 + 600 × raw / 44)`; easy: `round10(200 + 420 × raw / 44)` (tops out at 620). The owner approves or replaces these in this plan's review.
3. State lives in `private.mock_runs (group_id uuid pk, user_id, course_id, template_id, set_no, form_no, m1_attempt_id, m2_attempt_id, route text, raw_m1 int, m1_submitted_at, finished_at, created_at, unique (user_id, template_id, set_no, form_no))`. `attempts.score_raw` / `score_total` / `meta` of the module-1 attempt stay **null** until the run finishes, because students can select their own `attempts` rows.
4. RLS policy `attempt_answers: student selects own submitted` is replaced so a `mock_module` attempt's answers are readable only when its run has `finished_at`.
5. Mastery: the `attempts_mastery` trigger keeps ignoring `mock_module`; both modules' answers are fed to `private.apply_mastery` once, when module 2 finishes.
6. Access is checked only at `start_mock`. A started run can always be resumed, saved and submitted, also after the enrolment expires or renews.
7. One unfinished run at a time: starting another form raises `mock_in_progress`; calling `start_mock` for the form already in progress returns the current stage (idempotent, safe for two tabs — advisory lock per user).
8. New error codes: `mock_locked` (form not unlocked or not the next one), `mock_already_taken`, `mock_in_progress`. Existing `deadline_passed`, `not_enrolled`, `access_expired`, `invalid_input` are reused.
9. `get_attempt_review` is not changed here (Part 4).

## Interfaces (public RPCs, all `returns jsonb`, granted to `authenticated`)

- `get_mock_hub(p_course_id uuid)` → `{"set_no":n,"topics_passed":n,"forms":[{"form_no":n,"state":"locked|available|in_progress|finished","topics_needed":n,"group_id":uuid|null,"est_low":n|null,"est_high":n|null}]}`. Only published forms of the student's `mock_set_no`. Exactly one form can be `available`: the lowest not-started one, and only if unlocked and no run is in progress.
- `start_mock(p_course_id uuid, p_form_no int)` → a **stage** object (below).
- `get_mock_stage(p_group_id uuid)` → a stage object (resume after reload).
- `start_mock_module2(p_group_id uuid)` → a stage object (`module`, module 2). Valid during the gap; after the gap it returns the already-running module 2.
- `save_answer(...)` and `submit_attempt(p_attempt_id)` — existing signatures, extended to `mock_module`. For a mock module `submit_attempt` returns a stage object and no score.

**Stage object:**
- `{"stage":"module","group_id","module_no":1|2,"attempt_id","title","time_limit_s","deadline","server_now","warn_s","questions":[…],"answers":[{question_id,answer,marked,eliminated}],"client_seq"}`
- `{"stage":"gap","group_id","gap_ends_at","server_now"}`
- `{"stage":"finished","group_id"}`

**Private:**
- `private.mock_tick(p_user_id uuid) returns void` — for the user's unfinished run: module 1 past `started_at + time_limit_s + save_grace_s` → finish module 1; gap over and no module 2 → create module 2 with `started_at = m1_submitted_at + mock_gap_s`; module 2 overdue → finish module 2. Idempotent; takes the per-user advisory lock.
- `private.mock_finish_module1(p_group_id uuid, p_at timestamptz)` — null rows for unanswered, grade with `private.grade_answer`, store `raw_m1`, `route` (`raw_m1 >= blueprint.routing.threshold_correct_m1` → `M2H` else `M2E`), `m1_submitted_at = least(p_at, deadline)`, attempt `status = 'submitted'`.
- `private.mock_finish_module2(p_group_id uuid, p_at timestamptz)` — grade, write both attempts' `score_*`, insert `mock_results` (`route`, `raw_m1`, `raw_m2`, `est_low`, `est_high`, `domain_breakdown` = `{domain:{correct,total}}` from the form's slot recipe), apply mastery for both modules, set `finished_at`.
- `private.mock_estimate(p_route text, p_raw_total int) returns table(est_low int, est_high int)` — table by route, ± `mock_score_margin`, rounded to 10, clamped 200–800.
- `private.has_active_exam(p_user_id uuid) returns boolean` — a quiz attempt in progress, or a mock run without `finished_at` (includes the gap). For lane B (AI-03).
- `private.expire_overdue_attempts()` gains: `perform private.mock_tick(user_id)` for every user with an unfinished run that has something due.

## Review Focus

1. **Module 1 leak:** after submitting module 1, a direct `select` on `attempts` and `attempt_answers` as the student shows no `score_raw`, no `meta` report and no `is_correct` rows (Task 3).
2. **Student disappears:** in the gap → module 2 starts by itself and is submitted empty at its deadline, giving a result; during module 1 → module 1 is finished by the tick, same path (Task 3).
3. **Two tabs / double tap:** `start_mock` twice returns the same `attempt_id`; `submit_attempt` twice on module 1 does not re-route or change `raw_m1` (Tasks 2–3).
4. **Enrolment expires or `mock_set_no` changes mid-run:** save, submit and module 2 still work; the hub afterwards shows the new set (Task 3).
5. **Bad data:** an invalid scale table or a form with fewer than three module rows → `internal`, no partial run (Tasks 1–2).

---

### Task 0: Setup (router)

- [ ] Researcher (web): check the current College Board Digital SAT Math specification — 2 modules, 22 questions, 35 minutes each, domain mix — and report the source URL; any difference stops the plan and goes to the owner.
- [ ] Worktree `C:/Users/Lenovo/sat-wt-mock3` on `feat/MCK-01-mock-engine` from `origin/main`; copy this plan to `docs/superpowers/plans/2026-11-16-mock-engine-server.md`; commit, push, draft PR `feat(mock): MCK-01 mock exam engine (server)`.

### Task 1: Settings, scale, unlock, hub

**Files:** create `supabase/migrations/20261116100000_mck01_mock_engine.sql`, `supabase/tests/51_mock_engine.test.sql`.

**Produces:** the settings of Decisions 1–2 (+ spec rows, + a cross-check in `teacher_update_settings` only if one is natural); `private.mock_scale_ok`; `private.mock_estimate`; `private.mock_runs` (RLS enabled, no policy, no grants to API roles); `private.mock_form_unlock(p_user_id, p_course_id)` returning the published forms of the student's set with `k`, `topics_needed`; `get_mock_hub`.

- [ ] **Step 1: Failing tests.** Settings exist with the listed defaults and appear in `teacher_setting_spec()`; both seeded scale tables pass `mock_scale_ok`; `mock_scale_ok` is false for 44 entries, a value of 190, a value of 805, a decreasing pair, a non-array. `mock_estimate('M2H', 44)` = (770, 800); `('M2E', 44)` = (590, 650); `('M2H', 0)` = (200, 230). Hub for a student in set 1 with forms 1 and 3 published (2 draft) and defaults 3/3: 0 topics passed → both `locked`, `topics_needed` 3 and 6; 3 passed → form 1 `available`, form 3 `locked`; 6 passed → form 1 `available`, form 3 `locked` (only the lowest not-started form is available). Forms of another set and drafts never appear. No enrolment → `not_enrolled`. Anon cannot execute; `private.mock_runs` is not selectable by `authenticated`.
- [ ] **Step 2:** run → fail. **Step 3:** implement. **Step 4:** gates. **Step 5:** report.

### Task 2: Start, module payload, save, resume

**Consumes:** Task 1. **Produces:** `start_mock`, `get_mock_stage`, the `mock_module` branch of `save_answer`, the per-user advisory lock helper, `private.has_active_exam`.

- [ ] **Step 1: Failing tests** (fixture: one published form built with `teacher_assemble_mock_form` + publish as a teacher, a student with enough passed topics):
  - `start_mock` → stage `module`, `module_no` 1, 22 questions in the form's M1 slot order, `time_limit_s` = blueprint `M1.time_s`, `deadline = started_at + time_limit_s`, `warn_s` = `mock_warn_s`; the JSON text contains none of `correct_answer`, `explanation`, `is_correct`, `"key"`.
  - a `mock_runs` row exists; an `attempts` row of kind `mock_module`, `module_no` 1, `mock_form_id` = the M1 row, `mock_attempt_group` = `group_id`.
  - second `start_mock` (same form) → same `attempt_id`, still one run.
  - guards: locked form → `mock_locked`; form 2 while form 1 not started → `mock_locked`; another form while a run is unfinished → `mock_in_progress`; finished form → `mock_already_taken`; expired enrolment → `access_expired`; unknown form / draft form → `invalid_input`.
  - `save_answer` on the module: stores answer, mark and eliminated; stale `client_seq` → `{ok:true,stale:true}`; after `time_limit_s + save_grace_s` → `deadline_passed`; another student's attempt → refused as today.
  - `get_mock_stage` returns the same module with the saved answers and a later `server_now`; another student's `group_id` → `invalid_input`.
  - `has_active_exam` is true during the run, false for a student with nothing in progress.
- [ ] **Step 2–5** as in Task 1.

### Task 3: Submit, routing, gap, module 2, tick, results, leak guards

**Consumes:** Tasks 1–2. **Produces:** `mock_module` branch of `submit_attempt`, `start_mock_module2`, `private.mock_finish_module1/2`, `private.mock_tick`, the cron extension, the replaced `attempt_answers` policy, mastery at the end.

- [ ] **Step 1: Failing tests** (move time by updating `started_at` / `m1_submitted_at` as postgres, as `17_quiz.test.sql` and `18_expire_cron.test.sql` do):
  - submit module 1 with 14 correct → stage `gap`, `gap_ends_at = m1_submitted_at + mock_gap_s`; `mock_runs.route = 'M2H'`, `raw_m1 = 14`. With 13 correct → `M2E`.
  - **leak:** as the student, `select score_raw, meta from attempts` for module 1 → nulls; `select count(*) from attempt_answers` for that attempt → 0; `get_attempt_review` on it → refused.
  - submit module 1 again → same stage, `raw_m1` unchanged.
  - `start_mock_module2` during the gap → stage `module`, `module_no` 2, 22 questions of the routed module in slot order, `started_at = now`. After the gap (time moved) → module 2 with `started_at = m1_submitted_at + mock_gap_s`.
  - submit module 2 → stage `finished`; `mock_results` row with `route`, `raw_m1`, `raw_m2`, `est_low`/`est_high` equal to `mock_estimate`, `domain_breakdown` totals summing to 44; both attempts now carry `score_raw` / `score_total`; the student can now read `is_correct` for both modules; `skill_mastery` changed for a skill of a mock question (mock weight); hub shows the form `finished` with the range and the next form by the unlock rule.
  - **tick:** module 1 overdue → `mock_tick` finishes it and routes; gap over → module 2 created; module 2 overdue → finished with a result, unanswered counted wrong. `private.expire_overdue_attempts()` does the same for a user who calls nothing.
  - enrolment set to expired, and separately `mock_set_no` changed, in the middle of a run → save, submit and module 2 still succeed.
  - a quiz attempt's behaviour is unchanged (run `17_quiz` and `18_expire_cron` green).
- [ ] **Step 2–4** as above.
- [ ] **Step 5: Docs.** `docs/02-prd.md` MCK-09 (new unlock rule). `docs/06-data-model.md` (`private.mock_runs`, the changed policy). `docs/07` §1.1 (the RPCs + stage object) and §9 (three codes). `docs/08` §2/§5 (gap, tick, settings, scale tables are starting values), and the verified format source from Task 0. Report.

### Task 4: Review, PR, staging check (router)

- [ ] Gates myself after each task; diff review; commit per task; CI `db` green before the next task.
- [ ] `code-reviewer` on the branch (focus: leak paths, races on the advisory lock, cron cost). Fixes through the implementer. `docs/STATUS.md`. Mark ready and tell the owner.
- [ ] After merge and deploy: one rolled-back DO block in the staging SQL editor (owner signs in): as teacher assemble + publish a form; as a student with passed topics faked inside the transaction run hub → start → save → submit M1 → module 2 → submit → check `mock_results`; ends with `raise exception 'MOCK ENGINE OK …'`. Then a select proving no run, form or role change persisted.

## Verification

- `scripts/db-test.ps1`: `51_mock_engine` and the whole suite green; `supabase db lint` and `supabase db advisors` nothing new; `scripts/api-private-check.ps1` passes.
- CI green on the PR, including the demo seed step.
- Staging rolled-back script passes.

## Out of scope

Student hub / pre-exam / exam screen (3b), report and `get_attempt_review` for mocks (Part 4), reference sheet, Desmos, EST, calibrated scale tables, teacher editor for scale tables.
