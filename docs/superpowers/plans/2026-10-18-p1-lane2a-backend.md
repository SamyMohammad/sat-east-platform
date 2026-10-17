# Lane 2a — expiry cron, rate limiting, practice topic check, teacher unlock — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close four backend gaps from the P1 slice: quizzes expire on time without the student returning, practice/quiz RPCs are throttled, practice answers are tied to the attempt's topic, and a teacher can unlock a topic for one student.

**Architecture:** Three migrations in `supabase/migrations/`, each with a pgTAP file. Expiry reuses `private.finish_quiz`; cron runs plain SQL functions via `pg_cron`. Rate limiting is one `private` helper called at the top of five existing RPCs (redefined with `create or replace`, bodies otherwise unchanged).

**Tech Stack:** Postgres 15 (Supabase), plpgsql, pg_cron, pgTAP.

**Spec:** `docs/superpowers/specs/2026-10-18-p1-lane2-backend-design.md` §3–§6 (PR 2a). §7–§8 are PR 2b, not this plan.

**Context:** Lane 2 of the parallel lanes (`docs/STATUS.md`, PR #33). Worktree `C:/Users/Lenovo/sat-wt-lane2`, branch `feat/P1-lane2-backend` (spec committed `ff0f67c`). Executed by Codex via `codex-delegate` (one task per run, `--cd C:/Users/Lenovo/sat-wt-lane2`); Claude reviews and commits. Codex's sandbox has no Docker, so pgTAP runs on CI: after Task 1 Claude pushes and opens a **draft PR**; each later task is verified by CI on push.

## Global Constraints

- Every SQL file starts from `supabase/templates/` (`rpc.sql`, `setting.sql`, `test.sql`) and passes `docs/16` §2.
- `security definer`, `set search_path = ''`, fully-qualified names only.
- `private.*` functions: `revoke execute ... from public, anon, authenticated`. Public RPCs: `revoke ... from public, anon` + `grant execute ... to authenticated` (rule 9).
- Errors are raised as the bare `docs/07` §9 code (`raise exception 'rate_limited'`).
- No literals for tunables — read `settings` via `private.setting_int(key)` (rule 5). New keys seeded `on conflict (key) do nothing`.
- Reuse `save_grace_s` for expiry grace; do not add `attempt_grace_s`.
- Reserved names only: migrations `20261018100000_lane2a_expire_cron.sql`, `20261018100100_lane2a_rate_limit.sql`, `20261018100200_lane2a_teacher_unlock.sql`; tests `18_expire_cron`, `19_rate_limit`, `20_teacher_unlock`.
- Test names carry the requirement ID (`PRC-03:`, `LRN-05:`, `SEC:`).
- Update `docs/07` (RPC table, §2 cron row, settings mentions) in the same task as the function.
- Codex does not commit.

## Review Focus

1. A cron run racing a manual `submit_attempt` on the same quiz → graded once; cron skips it (Task 1 test: submitted attempt untouched, no error).
2. An attempt still inside `time_limit_s + save_grace_s` → not expired (Task 1 test).
3. Rate-limit windows are per user and per RPC key → user A hitting the limit does not block user B or another RPC (Task 2 test).
4. A practice answer for a question from another topic, smuggled into the attempt's `attempt_questions` → `invalid_input` (Task 2 test).
5. Teacher unlocks twice → first `unlocked_at` kept, one audit row (Task 3 test).

---

### Task 0: Land the plan (Claude)

- [ ] Copy this file to `docs/superpowers/plans/2026-10-18-p1-lane2a-backend.md` in the lane2 worktree, commit `docs(P1): lane 2a plan`.

### Task 1: Expiry cron + nightly cleanup (PRC-03)

**Files:**
- Create: `supabase/migrations/20261018100000_lane2a_expire_cron.sql`
- Create: `supabase/tests/18_expire_cron.test.sql`
- Modify: `docs/07-backend-logic-and-api.md` (§2 `cron-*` row: name the two jobs and functions)

**Interfaces:**
- Consumes: `private.finish_quiz(uuid, timestamptz)` (`20261017200100_prc03_quiz.sql:43`; raises `invalid_input` for non-`in_progress`), `private.setting_int(text)`, the cutoff used by `private.expire_quiz` (`started_at + time_limit_s + save_grace_s < now()`, finished at `started_at + time_limit_s`).
- Produces: `private.expire_overdue_attempts() returns int` (count finished), `private.nightly_cleanup() returns void`, setting `practice_stale_h` = 24, cron jobs `expire-attempts` (`* * * * *`) and `nightly-cleanup` (`0 2 * * *`, UTC).

- [ ] **Step 1: Write failing tests** in `18_expire_cron.test.sql` (fixtures like `17_quiz.test.sql`: own course/topic/questions with ids `...0018..`, one student). Assertions:
  - `PRC-03: overdue quiz is finished by cron` — attempt `kind='quiz'`, `in_progress`, `started_at = now() - interval '1 hour'`, `time_limit_s = 60`; after `select private.expire_overdue_attempts()` → returns `1`, status `submitted`, `submitted_at = started_at + 60s`, `meta->'report'` not null, `topic_progress.quiz_last_failed_at = started_at + 60s` (no answers ⇒ fail).
  - `PRC-03: quiz inside grace is not expired` — `started_at = now() - interval '80 seconds'`, `time_limit_s = 60` (grace 30) → stays `in_progress`.
  - `PRC-03: submitted quiz is skipped` — a `submitted` quiz attempt with past deadline → `lives_ok`, `submitted_at` unchanged.
  - `PRC-03: practice attempts are not touched by expiry`.
  - `PRC-03: stale practice abandoned` — practice attempt started 2 days ago, no answers → `abandoned` after `private.nightly_cleanup()`; one started 2 days ago with an answer `answered_at = now() - interval '1 hour'` → stays `in_progress`.
  - `SEC: old rate-limit windows purged` — `private.rate_limits` row `window_start = now() - interval '2 days'` deleted; row at `now()` kept.
  - `PRC-03: cron jobs scheduled` — `select count(*) from cron.job where jobname in ('expire-attempts','nightly-cleanup')` = 2.
  - `PRC-03: practice_stale_h defaults to 24`.
  - `SEC: cron functions not executable by authenticated` — `has_function_privilege('authenticated', 'private.expire_overdue_attempts()', 'execute')` is false.

- [ ] **Step 2: Implement the migration.**
  - `create extension if not exists pg_cron;` (Supabase installs it into `pg_catalog`; schema `cron`).
  - Seed `practice_stale_h` = `24`.
  - `expire_overdue_attempts()`: loop over `quiz`/`in_progress` attempts past the cutoff, ordered by `started_at, id`, `for update skip locked`; per attempt take the same advisory lock key `expire_quiz` uses (`'quiz:' || user_id || topic_id`) before calling `finish_quiz` — so it serialises with start/save/submit; re-check status after the lock and skip if no longer `in_progress`.
  - `nightly_cleanup()`: practice `in_progress` where `coalesce(max(attempt_answers.answered_at), started_at) < now() - practice_stale_h hours` → `abandoned`; `delete from private.rate_limits where window_start < now() - interval '1 day'`.
  - `cron.schedule('expire-attempts', '* * * * *', 'select private.expire_overdue_attempts()')`, `cron.schedule('nightly-cleanup', '0 2 * * *', 'select private.nightly_cleanup()')` — idempotent (unschedule-if-exists first, or rely on `cron.schedule` upsert-by-name).

- [ ] **Step 3: Verify (Claude):** push → CI `db` job: `supabase test db` all pass, `supabase db lint --fail-on error` clean, `scripts/api-private-check.ps1` equivalent step green. If `00_hardening_*`/`02_*` tests flag the `cron` schema, fix the migration (grants), not the hardening test.

- [ ] **Step 4: Commit (Claude)** `feat(P1): quiz expiry cron + nightly cleanup (PRC-03)`; open draft PR `feat(P1): lane 2a backend hardening (PRC-03, LRN-05)`.

### Task 2: Rate limiting + practice topic check (SEC, PRC-01, PRC-03)

**Files:**
- Create: `supabase/migrations/20261018100100_lane2a_rate_limit.sql`
- Create: `supabase/tests/19_rate_limit.test.sql`
- Modify: `docs/07-backend-logic-and-api.md` (note `rate_limited` on the five RPCs; settings keys)

**Interfaces:**
- Consumes: `private.rate_limits (key, window_start, count)`; current definitions of `public.get_practice_questions(uuid)` (`20261017100100_prc01_practice.sql:53`), `public.check_practice_answer(uuid, uuid, text, int)` (`20261017200000_prc03_grader_settings.sql:41`), `public.start_quiz(uuid)`, `public.save_answer(...)`, `public.submit_attempt(uuid)` (`20261017200100_prc03_quiz.sql:178/263/317`).
- Produces: `private.hit_rate_limit(p_key text, p_limit int, p_window_s int) returns void`; settings `rate_answer_per_min` = 30, `rate_start_per_min` = 10, `rate_save_per_min` = 120, `rate_submit_per_min` = 10.

- [ ] **Step 1: Write failing tests.**
  - `SEC: hit_rate_limit allows up to the limit` — `hit_rate_limit('t:a', 2, 60)` twice `lives_ok`; third `throws_ok(..., 'P0001', 'rate_limited')`.
  - `SEC: keys are independent` — after `t:a` is exhausted, `hit_rate_limit('t:b', 2, 60)` `lives_ok`.
  - `SEC: check_practice_answer rate limited` — set `rate_answer_per_min` to `1` in-test; authenticate as student, first call OK, second (different question) → `rate_limited`.
  - `SEC: per user` — a second student's first call still OK.
  - `SEC: start_quiz rate limited` — `rate_start_per_min` = `1`; second `start_quiz` → `rate_limited` (the first may resume or raise a gate code; assert only the second raises `rate_limited`).
  - One `rate_limited` test each for `get_practice_questions`, `save_answer`, `submit_attempt` with the limit set to `0` in-test (first call raises).
  - `PRC-01: practice answer must belong to the attempt topic` — insert a published practice question of **another** topic into the attempt's `attempt_questions`; `check_practice_answer` → `invalid_input`.
  - `PRC-01: same new question answered twice counts once` — two tries on one question → `topic_progress.practice_count` = 1.
  - Settings defaults: the four keys equal `30, 10, 120, 10`.
  - `SEC: hit_rate_limit not executable by authenticated`.

- [ ] **Step 2: Implement.**
  - `hit_rate_limit`: `window_start = to_timestamp(floor(extract(epoch from now()) / p_window_s) * p_window_s)`; `insert ... on conflict (key, window_start) do update set count = rate_limits.count + 1 returning count`; raise `rate_limited` if `count > p_limit`.
  - Redefine the five RPCs with their **current bodies unchanged** plus, right after the `not_authenticated` check: `perform private.hit_rate_limit('<rpc_name>:' || v_uid, private.setting_int('<key>'), 60);` — `check_practice_answer` → `rate_answer_per_min`; `get_practice_questions`, `start_quiz` → `rate_start_per_min`; `save_answer` → `rate_save_per_min`; `submit_attempt` → `rate_submit_per_min`. Keep existing grants/revokes.
  - In `check_practice_answer` add `and q.topic_id = v_att.topic_id` to the question lookup.

- [ ] **Step 3: Verify (Claude):** push; CI `db` green, including the unchanged `16_practice` and `17_quiz` suites (a default limit must not trip them — if one does, raise nothing in the test, check the default).

- [ ] **Step 4: Commit (Claude)** `feat(P1): rate limits on practice and quiz RPCs`.

### Task 3: Teacher unlock (LRN-05, L-9)

**Files:**
- Create: `supabase/migrations/20261018100200_lane2a_teacher_unlock.sql`
- Create: `supabase/tests/20_teacher_unlock.test.sql`
- Modify: `docs/07-backend-logic-and-api.md` (RPC table row)

**Interfaces:**
- Consumes: `public.is_teacher()`, `public.topic_progress (unlocked_at, unlocked_by)`, `public.audit_log (actor, action, entity, entity_id, diff)`, `private.topic_states(uuid, uuid)` (already treats `unlocked_at is not null` as open).
- Produces: `public.teacher_unlock_topic(p_student_id uuid, p_topic_id uuid) returns jsonb` → `{topic_id, unlocked_at, unlocked_by}`.

- [ ] **Step 1: Write failing tests** (course with two published topics; topic 2 locked for the student).
  - `LRN-05: anon gets not_authenticated`; `LRN-05: student gets forbidden`.
  - `LRN-05: unknown student → invalid_input`; `LRN-05: teacher as target → invalid_input` (target must be a `student` profile); `LRN-05: unpublished topic → invalid_input`; null args → `invalid_input`.
  - `LRN-05: teacher unlocks` — returns `topic_id`, non-null `unlocked_at`, `unlocked_by` = teacher uid; `private.topic_states(student, course)` shows topic 2 `open`.
  - `LRN-05: unlock is idempotent` — second call returns the same `unlocked_at`; `audit_log` has exactly 1 row `action = 'topic.unlock'`, `entity = 'topic'`, `entity_id` = topic 2, `diff->>'student_id'` = student uid.
  - `LRN-05: existing progress row kept` — student with `practice_count = 3` on topic 2 before unlock keeps 3.
  - `SEC: execute granted to authenticated, not anon`.

- [ ] **Step 2: Implement** from `templates/rpc.sql`: auth check → `is_teacher()` else `forbidden` → validate target profile role `student` and topic `is_published` → `insert ... on conflict (user_id, topic_id) do update set unlocked_at = coalesce(topic_progress.unlocked_at, now()), unlocked_by = coalesce(topic_progress.unlocked_by, auth.uid())`; audit only when this call set it. Re-locking is out of scope.

- [ ] **Step 3: Verify (Claude):** CI `db` green.

- [ ] **Step 4: Commit (Claude)** `feat(P1): teacher unlocks a topic for a student (LRN-05)`; update `docs/STATUS.md` row in the lane PR; mark PR ready for review.

## Verification (end to end)

- CI on the draft PR: `db` job (`supabase test db` incl. 18–20 and all existing suites, `supabase db lint --fail-on error`, private-schema REST check) green; `client`/`functions` jobs unaffected.
- Claude review per task: `git diff --stat`, then hunks against the task; confirm the five redefined RPC bodies differ from the previous migration only by the rate-limit line (and the topic filter) — `diff` the function bodies.
- After merge, staging: `select jobname, schedule from cron.job;` shows both jobs; start a quiz on staging, leave, confirm it is submitted within ~1 min after the deadline + 30 s.
