# Lane 2b — review set after a failed quiz + get_attempt_review — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After a failed quiz the student must finish a targeted review set (practice-style, on the missed skills) before the retake; a submitted quiz can be reviewed, with keys/explanations only once the topic's quiz is passed.

**Architecture:** Two migrations. The first adds `start_review`, lets `check_practice_answer` serve `review` attempts, and rewrites `private.quiz_state` (+ `start_quiz` gate, `get_topic` payload) for the new `review_needed` state. The second adds `get_attempt_review`. All logic stays in SQL; no Flutter.

**Tech Stack:** Postgres 15 (Supabase), plpgsql, pgTAP.

**Spec:** `docs/superpowers/specs/2026-10-18-p1-lane2-backend-design.md` §7–§8 (user chose option 2 for §8).

**Context:** Lane 2, PR 2b. PR 2a (#35) merged at `66f4644`. Worktree `C:/Users/Lenovo/sat-wt-lane2`, branch `feat/P1-lane2b-review` (from `origin/main`). Codex implements via `codex-delegate` (thread `01a14c23-…`); Claude reviews/commits; CI on a draft PR runs pgTAP (no Docker for Codex).

## Global Constraints

- Same as plan 2a: templates in `supabase/templates/`, `docs/16` §2, `security definer` + `set search_path = ''`, bare §9 error codes, settings via `private.setting_int`, private functions revoked from `public, anon, authenticated`, public RPCs revoked from `public, anon` and granted to `authenticated`.
- Redefinitions start from the **latest** body (`20261018100100_lane2a_rate_limit.sql` for `check_practice_answer`, `start_quiz`; `20261017200100_prc03_quiz.sql` for `quiz_state`, `get_topic`) and keep the 2a rate-limit lines.
- Reserved: migrations `20261018200000_lrn04_review_set.sql`, `20261018200100_prc03_attempt_review.sql`; tests `21_review_set`, `22_attempt_review`; new error codes `review_needed`, `attempt_not_submitted` (add to `docs/07` §9); settings `review_per_skill` = 2, `review_max` = 10.
- Rule 1: keys/explanations leave the server only through `check_practice_answer` (practice + review, per its reveal rules) and `get_attempt_review` (only when passed).

## Review Focus

1. A student who failed, then passed on a retake → `get_attempt_review` on the **old failed** attempt now returns keys (rule is "topic passed", not "this attempt passed") — test it.
2. Teacher unlocked the next topic but the student failed this quiz → review still required here (Task 1 test).
3. Two concurrent `start_review` calls → one review attempt (advisory lock, same pattern as `expire_quiz`).
4. Review answers never change `practice_count` (Task 1 test), and a review question answered first in review then in practice does count in practice.
5. Another student's attempt id in `get_attempt_review` → `forbidden`, never data (Task 2 test).

---

### Task 0: Land the plan (Claude)

- [ ] Copy to `docs/superpowers/plans/2026-10-18-p1-lane2b-review.md`, commit `docs(P1): lane 2b plan`.

### Task 1: Review set (LRN-04, L-7)

**Files:**
- Create: `supabase/migrations/20261018200000_lrn04_review_set.sql`, `supabase/tests/21_review_set.test.sql`
- Modify: `docs/07-backend-logic-and-api.md` (rows: `start_review` new; `check_practice_answer`, `get_topic`, `start_quiz` updated; §9 `review_needed`)

**Interfaces:**
- Consumes: `private.practice_access(uuid, uuid) returns uuid` (course id), `private.expire_quiz`, `private.hit_rate_limit`, `public.question_skills`, `public.question_exposure`, `topic_progress.quiz_last_failed_at / quiz_passed_at`.
- Produces:
  - `private.review_status(p_uid uuid, p_topic_id uuid) returns jsonb` → `{required bool, attempt_id uuid|null, answered int, total int}`; `required` = `quiz_passed_at is null and quiz_last_failed_at is not null and not exists (review attempt for this topic with status 'submitted' and submitted_at >= quiz_last_failed_at)`.
  - `public.start_review(p_topic_id uuid) returns jsonb` → same shape as `get_practice_questions` (`attempt_id`, `rep_target`, `questions[...]`, no keys) plus `answered` (question ids already final, for resume).
  - `private.quiz_state` order: `in_progress → practice_needed → review_needed → cooldown → available`; when `review_needed` it still includes `available_at` if the cooldown is running, and always includes `review` (from `review_status`).
  - `start_quiz` raises `review_needed`.

- [ ] **Step 1: Write failing tests** (`21_review_set.test.sql`; fixture: course, topic with ≥ 3 skills, practice pool with 3 questions per skill, quiz pool, student enrolled, `practice_count` ≥ `practice_min`; a failed quiz attempt built through `start_quiz` + `save_answer` + `submit_attempt` or by direct inserts + `private.finish_quiz`). Assertions:
  - `LRN-04: failed quiz → state review_needed` (with `available_at` present while cooldown runs).
  - `LRN-04: start_quiz raises review_needed`.
  - `LRN-04: start_review draws review_per_skill per missed skill` — 2 missed skills → 4 questions, all `pool='practice'`, all tagged with a missed skill; attempt `kind='review'`, `meta->>'source_attempt_id'` = failed quiz id; no `key`/`explanation_md`/`hint_md` keys in output.
  - `LRN-04: capped at review_max` — set `review_max` = 3 in-test → 3 questions.
  - `LRN-04: short pool filled from topic practice pool`; `LRN-04: empty practice pool → pool_exhausted`.
  - `LRN-04: all-blank fail → every quiz question's skills count as missed`.
  - `LRN-04: start_review resumes the in-progress review` (same `attempt_id`, same questions).
  - `LRN-04: start_review when not required → invalid_input` (never failed / passed / review already submitted).
  - `LRN-04: check_practice_answer serves review attempts` — wrong then wrong → reveals key on try 2.
  - `LRN-04: review answers don't change practice_count`.
  - `LRN-04: last final answer submits the review` → attempt `submitted`; state falls to `cooldown` (cooldown running) or `available` (set `quiz_last_failed_at` 13 h back).
  - `LRN-04: teacher unlock does not skip review` — `teacher_unlock_topic` on this topic, state still `review_needed`.
  - `LRN-04: passing later clears review_needed` — set `quiz_passed_at` → state not `review_needed`.
  - `LRN-04: get_topic exposes quiz.review {attempt_id, answered, total}`.
  - Settings defaults `review_per_skill` = 2, `review_max` = 10; `SEC: start_review rate limited` (`rate_start_per_min` = 0 in-test); grants (authenticated yes, anon no).

- [ ] **Step 2: Implement.**
  - `start_review`: auth → `hit_rate_limit('start_review:'||uid, rate_start_per_min, 60)` → null check → `private.practice_access` → `pg_advisory_xact_lock(hashtextextended('review:'||uid||topic,0))` → `expire_quiz` → `review_status`; not required → `invalid_input`; in-progress review → return it; else source = latest submitted quiz attempt on the topic; missed skills = `question_skills` of its `attempt_answers` with `is_correct` false; per skill pick `review_per_skill` published practice questions of the topic (unseen-by-user first, then random, distinct across skills), cap `review_max`, fill remaining slots up to `least(review_max, review_per_skill * n_missed_skills)` from any published practice question of the topic; 0 → `pool_exhausted`. Insert attempt (`kind 'review'`, `status 'in_progress'`, `meta {source_attempt_id}`), `attempt_questions`, `question_exposure`.
  - `check_practice_answer`: accept `a.kind in ('practice','review')`; `v_counts` only when `v_att.kind = 'practice'`; after writing a final answer (correct or try 2) on a `review` attempt, if every `attempt_questions` row has a final answer → `status 'submitted', submitted_at now()`.
  - `quiz_state`: insert the `review_needed` step after `practice_needed`; add `review` to the payload. `start_quiz`: raise `review_needed` when state is `review_needed`. `get_topic`: unchanged body (it already returns `v_quiz`) unless needed.

- [ ] **Step 3: Verify (Claude):** draft PR → CI `db` green incl. unchanged `16_practice`, `17_quiz`, `19_rate_limit`. Diff redefined bodies vs latest priors (script from 2a review).
- [ ] **Step 4: Commit (Claude)** `feat(P1): review set after a failed quiz (LRN-04)`; open draft PR `feat(P1): lane 2b review set + attempt review (LRN-04, PRC-03)`.

### Task 2: get_attempt_review (PRC-03, user decision option 2)

**Files:**
- Create: `supabase/migrations/20261018200100_prc03_attempt_review.sql`, `supabase/tests/22_attempt_review.test.sql`
- Modify: `docs/07-backend-logic-and-api.md` (`get_attempt_review` row replaced; §9 `attempt_not_submitted`)

**Interfaces:**
- Consumes: `attempts.meta->'report'` (from `finish_quiz`), `attempt_answers (answer->>'value', is_correct, time_ms)`, `private.question_keys`, `question_skills`/`skills (code, name)`, `topic_progress.quiz_passed_at`.
- Produces: `public.get_attempt_review(p_attempt_id uuid) returns jsonb` →
  `{summary: {score_raw, score_total, score_pct, pass_mark, passed, keys_visible}, questions: [{id, type, stem_md, choices[{label, body_md}], my_answer, is_correct, time_ms, skills[{code, name}], key?, explanation_md?}]}` ordered by `position`. `key` uses the practice shape (`{choice}` / `{text}` = first accepted form). `key` and `explanation_md` are **absent** (not null) unless `keys_visible`.

- [ ] **Step 1: Write failing tests.**
  - `PRC-03: anon → not_authenticated`; `PRC-03: other student's attempt → forbidden`; null / unknown id → `invalid_input`.
  - `PRC-03: in_progress quiz → attempt_not_submitted`; non-quiz attempt → `invalid_input`.
  - `PRC-03: failed, not passed → no keys` — `keys_visible` false; no question object has `key` or `explanation_md`; `is_correct`, `my_answer`, `skills` present.
  - `PRC-03: passed → keys` — `keys_visible` true; MCQ `key = {"choice": ...}`, SPR `key = {"text": first accepted}`, explanations present.
  - `PRC-03: old failed attempt shows keys after a later pass` (Review Focus 1).
  - `PRC-03: teacher unlock is not a pass` — unlock topic, failed attempt still `keys_visible` false.
  - `PRC-03: blank answer → my_answer null, is_correct false`.
  - `PRC-03: summary matches the stored report`.
  - Grants.

- [ ] **Step 2: Implement** from `templates/rpc.sql`: auth → null check → load attempt (`invalid_input` if missing / not `quiz`) → owner else `forbidden` → status `submitted` else `attempt_not_submitted` → `keys_visible := quiz_passed_at is not null` for (owner, topic) → build JSON. Add `rate_limited`? Not needed (read-only, cheap) — skip.
- [ ] **Step 3: Verify (Claude):** CI `db` green.
- [ ] **Step 4: Commit (Claude)** `feat(P1): attempt review with keys after pass (PRC-03)`; mark PR ready.

## Verification (end to end)

- CI on the draft PR: `supabase test db` (new 21, 22 + all prior), `db lint`, private-schema REST check green.
- Claude review: `git diff --stat`, hunks vs tasks, body-diff script for redefined functions (only the intended lines change).
- After merge, staging (user, demo course): fail a quiz → topic shows review needed → `start_review` questions are on the missed skills → finish → retake gated by cooldown only; `get_attempt_review` shows no keys until a pass. Flutter UI for S-23 comes in a later lane-1 PR.
