# Plan — Mock part 3a: engine server (MCK-01/03/09)

## Context
Mock parts 1 (assembly, #87) and 2 (teacher screen, #88) are merged. Part 3 (student takes the mock)
is split: **3a = server** (this plan), **3b = client** (hub, pre-exam, mock mode in `QuestionView`,
settings list field) gets its own plan. Spec: `docs/superpowers/specs/2026-11-12-mock-sat-design.md` Part 3.
College Board check done (framework PDF + satsuite pages): 22 q / 35 min per module, MST adaptive,
75/25 MCQ/SPR, 35/35/15/15 domains, no break between modules, reference sheet, Desmos graphing or
scientific. Our mock scores all 22 (official: 20 + 2 pretest) → raw 0–44; 8/8/3/3 per module is
proportionally right. Kept on purpose; recorded in `docs/08`.

## Setup
- Worktree `C:/Users/Lenovo/sat-wt-mock3a`, branch `feat/MCK-03-mock-engine` from `main` (9133e15).
- Reserved migrations: `20261113100000_mck03_mock_settings.sql`, `20261113100100_mck03_mock_engine.sql`,
  `20261113100200_mck03_mock_expiry.sql`. Tests: `supabase/tests/51_mock_settings.test.sql`,
  `52_mock_engine.test.sql`, `53_mock_expiry.test.sql`. Every SQL file starts from `supabase/templates/`.
- Implementer = `implementer` agent (Sonnet), pgTAP tests first, no commits. Draft PR early — CI `db` job is
  the pgTAP source of truth (local `supabase start` exits 139).

## Existing code to reuse (live definitions)
- `start_quiz` payload shape — `20261105100000_crs06_free_preview.sql:404-494`.
- `save_answer` (seq upsert, grace) — `20261102100000_p1_homework.sql:275-330`.
- `submit_attempt` dispatcher — same file :332-401; `private.grade_answer` (`20261017200000_prc03_grader_settings.sql:10`).
- `private.apply_mastery(...)` maps `mock_module → 'mock'` (`20261103100000_anl01_mastery.sql:42`).
- `private.expire_overdue_attempts()` + cron `expire-attempts` (`20261018100000_lane2a_expire_cron.sql`).
- `private.topic_states(uid, course)` → `status='completed'` = passed topic.
- `public.has_access(course)`, `enrollments.mock_set_no`, `private.setting_int`, `private.hit_rate_limit`.
- Mock tables: `mock_forms(set_no, form_no, module, question_ids[], status)`, `mock_results`, `attempts(mock_attempt_group, mock_form_id, module_no)`; `attempt_kind` already has `mock_module`.

## Task 1 — Settings + scoring helpers (`…100000_mck03_mock_settings.sql`, test 51)
New `settings` rows (by migration; editing the unlock list on screen comes in 3b; scale tables stay
migration-only for the beta per spec):
- `mock_unlock_topics` = `[3, 6, 10]`; `mock_gap_s` = `120`; `sat_scale_margin` = `30`.
- `sat_scale_easy`, `sat_scale_hard`: 45 ints (raw 0–44), non-decreasing, 200–800. **Starting values (owner approves here):**
  - easy: linear 200 → 620 over raw 0–35, then linear to 650 at 44 (raw > 35 is unreachable on the easy route).
  - hard: linear 200 → 480 over raw 0–14 (unreachable below 14), then linear 480 → 800 over 14–44.
  - Values rounded to 10.
- Helpers (private, no grants): `setting_json(key) jsonb`; `mock_scale_ok(jsonb) bool` (45 entries, ints,
  200–800, non-decreasing); `mock_unlock_need(k int) int` (list[min(k,len)]); `mock_score(route, raw) → (est_low, est_high)`
  (±margin, round 10, clamp 200–800).
- Tests: valid seeds, validator rejects bad tables, unlock beyond list uses last, clamp/round edges.

## Task 2 — Engine RPCs (`…100100_mck03_mock_engine.sql`, test 52)
State lives on `attempts`: a mock = group id; M1 row (`module_no=1`), M2 row (`module_no=2`). M1 `meta.route`
set at M1 finish; `meta.gap_until = m1_submitted_at + mock_gap_s`. Unique partial index:
one M1 attempt per `(user_id, mock_form_id)`.
- `private.mock_lock(uid)` advisory key `'mock:'||uid`.
- `private.mock_tick(uid)`: under the lock — finish an overdue in-progress module (`started_at+time_limit_s+save_grace_s < now()`,
  submitted at its deadline); if a gap has ended with no M2, create M2 with `started_at = gap_until` (and finish it too if
  already overdue). Called first by every mock RPC and by the cron.
- `private.finish_mock_module(attempt_id, submitted_at)`: fill unanswered, grade with `grade_answer`, set scores.
  M1 → route (`correct ≥ blueprint.routing.threshold_correct_m1` → M2H else M2E), set gap. M2 → insert `mock_results`
  (route, raw_m1, raw_m2, est_low/high from `mock_score`, `domain_breakdown` per domain correct/total), then call
  `apply_mastery` for both modules' answers once. Mastery trigger `attempts_mastery` stays excluding `mock_module`.
- `private.has_active_exam(uid) bool`: quiz in progress, mock module in progress, or open gap (for lane B AI-03).
- Public RPCs (each: `grant execute … to authenticated`, rate limited with existing `rate_*` settings):
  - `get_mock_hub(p_course_id)` → `{passed_topics, forms:[{form_no, k, state: locked|available|in_progress|finished, need}], active_group}`.
    Form k = k-th published `form_no` in the student's `mock_set_no` (all three module rows published). Needs active enrolment.
  - `start_mock(p_course_id)` → if a mock is unfinished, returns it (resume); else picks the lowest unstarted available
    form, creates M1 (`time_limit_s = blueprint.modules.M1.time_s`), writes `question_exposure`, returns the session.
  - `get_mock_session(p_group_id)` → `{stage:'module', module_no, …quiz-shaped payload incl. eliminated}` |
    `{stage:'gap', gap_until, server_now}` | `{stage:'finished', result_id}`. No route, scores or keys before M2 ends.
  - `start_mock_module2(p_group_id)` → early start during the gap; idempotent.
  - `save_answer`: new `mock_module` branch (no topic/access check — a started mock always ends; deadline + grace as quiz;
    persists `eliminated`). `submit_attempt`: `mock_module` branch → `finish_mock_module`, returns only the next stage.
- RLS: `attempt_answers` student-select policy also requires, for `mock_module`, a `mock_results` row for the group.
  `get_attempt_review` already refuses `mock_module` (part 4 adds it).
- New error codes in `docs/07` §9: `mock_locked`, `mock_none_available`. Reuse `not_enrolled`, `deadline_passed`, `attempt_closed`.
- Tests: unlock gating, form order with gaps, one attempt per form, resume, no M1 data before finish (RLS + session),
  route both ways, gap auto-start at `gap_until`, early start, deadline submit, results math, mastery applied once,
  expired enrolment mid-mock still finishes, `has_active_exam` cases, grants.

## Task 3 — Expiry (`…100200_mck03_mock_expiry.sql`, test 53)
- Extend `expire_overdue_attempts()` with a mock loop: distinct users with an overdue mock module or an ended gap →
  `mock_tick(uid)` (try-lock, skip if busy). Partial index `where kind='mock_module' and status='in_progress'`.
- Tests with `tests.freeze_time`: cron finishes overdue M1, auto-starts M2 after gap, finishes overdue M2 → result.

## Task 4 — Docs (same PR)
- `docs/08`: verified format with source URLs, all-22-scored decision, calculator wording, unlock rule, gap, scoring settings.
- `docs/02` MCK-09 → topic-count unlock list. `docs/06`: form status, attempts mock usage, results. `docs/07`: RPCs + codes.
- `docs/STATUS.md`: lane A row → part 2 merged (#88), part 3a in review.

## Verification
- Router runs: `git diff --stat`, reads hunks, `scripts/db-test.ps1` if local DB starts, else CI `db` job on the draft PR.
- `scripts/api-private-check.ps1` (private helpers not on REST).
- Staging check after merge: begin…rollback SQL script as a demo student (`set_config('request.jwt.claims')`) —
  start, save, submit M1, wait gap via frozen times, M2, result row.
- Then `code-reviewer` agent, PR ready, user merges; then plan 3b.
