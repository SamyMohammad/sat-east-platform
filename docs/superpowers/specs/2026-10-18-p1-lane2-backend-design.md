# Lane 2 — backend follow-ups after the P1 slice (design)

Status: draft · 2026-10-18 · Lane 2 of the parallel lanes in `docs/STATUS.md`
Reqs: LRN-04 (L-7), LRN-05 (L-9), PRC-03 follow-ups, `docs/16` rate limiting
Scope: `supabase/` and `docs/` only — no Flutter. UI for these lands in lanes 1 and 3.

## 1. Intent

The Phase 1 slice works end to end, but it left backend gaps listed under *Open* in `STATUS.md`:
timed quizzes only expire when the student comes back, practice RPCs are unthrottled,
`practice_count` can race, a failed quiz only gives a 12 h cooldown (no review), the teacher can't
unlock a topic, and nothing returns a graded quiz for review. This lane closes those gaps on the
server so the student and teacher UIs can be built on top.

## 2. Split into two PRs

| PR | Contents | Product decisions |
|----|----------|-------------------|
| **2a** (mechanical) | §3 expiry cron · §4 rate limiting · §5 practice_count lock + pool re-check · §6 teacher unlock | none |
| **2b** (product) | §7 review set after a failed quiz · §8 `get_attempt_review` | user decided §8 |

2a and 2b touch different functions except `start_quiz`/`check_practice_answer`
(2a adds a rate-limit call, 2b adds a review gate / review attempts). 2b branches from `main`
**after 2a merges** and redefines functions with `create or replace` on top of 2a's versions
(keeping 2a's rate-limit calls). Within 2b, the review-set migration owns `quiz_state`; the
attempt-review migration does not touch it.

## 3. Expire overdue attempts (`cron-expire-attempts`)

- Enable `pg_cron` in a migration (`create extension if not exists pg_cron`; Supabase supports it).
- `private.expire_overdue_attempts()` — finds `quiz` attempts `in_progress` whose deadline +
  `settings.attempt_grace_s` has passed and finishes each through the existing
  `private.finish_quiz(attempt_id, deadline)` path (or `private.expire_quiz`), so cron-expired and
  lazily expired attempts produce the same report, cooldown and progress writes. The cutoff must be
  **exactly** the one `expire_quiz`/`quiz_state` use today (`deadline + save_grace_s`). Must be safe
  against a concurrent `submit_attempt`: finish_quiz locks `for update`; the builder verifies it
  returns early for a non-`in_progress` attempt and adds a test if not.
- Nightly `private.close_stale_practice()` — practice attempts `in_progress` with no answer for
  `settings.practice_stale_h` hours → status `abandoned`. Also deletes `private.rate_limits` rows
  older than one day.
- Schedules: `expire-attempts` every minute, `nightly-cleanup` once a day (UTC).
- Grace: **reuse the existing `save_grace_s`** (30) — no new grace key. New setting:
  `practice_stale_h` = 24.
- Tests call the functions directly; pgTAP does not wait for the scheduler. One test asserts the two
  jobs exist in `cron.job`.

## 4. Rate limiting (`private.hit_rate_limit`)

- `private.hit_rate_limit(p_key text, p_limit int, p_window_s int)` — fixed window over the existing
  `private.rate_limits (key, window_start, count)` table; upsert-increments the current window and
  raises `rate_limited` (already in `docs/07` §9) when `count > p_limit`. The raise rolls back the
  increment, so denied calls don't count — accepted.
- Key = `<rpc>:<auth.uid()>`. Applied at the top of (after auth check):
  `check_practice_answer`, `get_practice_questions`, `start_quiz`, `save_answer`, `submit_attempt`.
- Limits from `settings` (per minute): `rate_answer_per_min` = 30 (check_practice_answer),
  `rate_start_per_min` = 10 (get_practice_questions, start_quiz), `rate_save_per_min` = 120
  (save_answer — autosave is chatty), `rate_submit_per_min` = 10.
- Internal: no grants; `private` schema.

## 5. `practice_count` + pool re-check (deferred from part 4)

Mostly already built: `check_practice_answer` takes an advisory lock on (user, question), re-checks
`pool = 'practice' and status = 'published'`, and increments `practice_count` atomically
(`+ 1` in the upsert). Remaining work only:
- Add the missing check that the question belongs to the attempt's topic (else `invalid_input`).
- Add a pgTAP test that answering the same new question twice counts once (proves the lock).
No lock re-keying.

## 6. Teacher unlock (L-9, LRN-05)

- `public.teacher_unlock_topic(p_student_id uuid, p_topic_id uuid) returns jsonb`
  → `{topic_id, unlocked_at, unlocked_by}`.
- Caller must be a teacher (`public.is_teacher()`; there is no admin role in `user_role`) → else
  `forbidden`.
  Student must exist and the topic must be published → else `invalid_input`.
- Upserts `public.topic_progress.unlocked_at = now(), unlocked_by = auth.uid()`; idempotent (a
  second call keeps the first `unlocked_at`). `private.topic_states` already treats
  `unlocked_at is not null` as open — no change there.
- Writes `public.audit_log` (`action = 'topic.unlock'`, `entity = 'topic'`, `entity_id` = topic id,
  `diff = {student_id, unlocked_at}`).
- Unlock only; re-locking is a non-goal. `grant execute ... to authenticated` (rule 9).

## 7. Review set after a failed quiz (L-7, LRN-04) — PR 2b

**Behaviour (Claude's proposal, user did not object):**
- After a failed quiz, the student must complete a **review set** before the retake. The cooldown
  (`settings.cooldown_h`, 12 h) still counts from the fail time and runs **in parallel** — the
  retake opens when both are satisfied.
- "Complete" = every review question answered (right or wrong, practice rules: retry once, then
  reveal). Not a pass/fail gate.

**When a review is required (Claude's calls):**
- Every failed quiz, including one that ended by expiry (cron or lazy) — expiry grades it and sets
  `quiz_last_failed_at`, so it is a fail like any other.
- Once the topic's quiz is passed, review is never required again (state is decided by the pass).
- A teacher unlock (§6) opens the topic for access; it does **not** skip the review or cooldown of
  that topic's quiz.
- A fail with no wrong answers can't happen; an all-blank fail treats every quiz question as missed.
  Missed questions with no `question_skills` rows contribute nothing; the fill rule below covers it.

**State display:** `review_needed` is shown while the review is outstanding, even while the
cooldown is also running (`get_topic.quiz.available_at` is still returned so the UI can show both).
After the review is submitted the state falls through to `cooldown` or `available`.

**Drawing questions** — `public.start_review(p_topic_id uuid)`:
- Allowed only when the latest submitted quiz on the topic failed, the topic isn't passed, and no
  review attempt has been submitted since `quiz_last_failed_at`. Resumes an in-progress review.
- Missed skills = `question_skills` of the failed attempt's questions answered wrong or blank.
- Draw `settings.review_per_skill` (2) published `practice`-pool questions of the topic per missed
  skill, unseen-in-review first, capped at `settings.review_max` (10). If the pool is short, fill
  from the topic's practice pool; if still empty → `pool_exhausted`.
- Creates an attempt `kind = 'review'` with `meta.source_attempt_id` = the failed quiz attempt.
- Returns the same shape as `get_practice_questions` (no keys/explanations/hints).

**Answering:** `check_practice_answer` accepts `review` attempts with the same reveal rules.
Review answers do **not** add to `practice_count`. When the last question gets its final answer
(correct, or second miss), the server marks the review attempt `submitted`.

**Quiz state:** `private.quiz_state` priority becomes
`in_progress → practice_needed → review_needed → cooldown → available`.
`start_quiz` raises new code `review_needed` (add to `docs/07` §9). `get_topic.quiz` exposes
`state = 'review_needed'` plus `review: {attempt_id?, answered, total}`.

## 8. `get_attempt_review` (user decision: option 2)

`public.get_attempt_review(p_attempt_id uuid) returns jsonb` — the only post-submit path that may
return keys (rule 1).

- Caller must own the attempt (`forbidden`); attempt must be `submitted` or `expired`
  (new code `attempt_not_submitted`, add to `docs/07` §9). Kinds in scope: `quiz` (practice and
  review already reveal per question; homework later).
- Per question: `id, type, stem_md, choices`, `my_answer`, `is_correct`, `skills[{code,name}]`,
  `time_ms` if recorded.
- **Keys rule (user's choice):** `correct_answer` and `explanation_md` are included **only when the
  student has passed this topic's quiz** (`topic_progress.quiz_passed_at is not null`). After a fail
  the student sees right/wrong and skills only — the review set (§7) teaches, with full feedback.
  A teacher unlock does not count as a pass.
- Summary block: `score_raw, score_total, score_pct, pass_mark, passed, keys_visible`.

## 9. Goals / non-goals / anti-goals

- Goals: close the five *Open* backend items; keep every rule in SQL with pgTAP tests.
- Non-goals: any Flutter (S-23 review screen, teacher unlock button), spiral/difficulty blueprint,
  homework review, re-locking, per-user rate-limit overrides, mock attempts.
- Anti-goals (fail even if it "works"): a quiz key reachable before the topic is passed; a cron
  run and a manual submit grading the same attempt twice; review answers inflating `practice_count`;
  limits hard-coded instead of read from `settings` (rule 5).

## 10. Reserved names (parallel-lane protocol)

- Migrations: `20261018100000_lane2a_expire_cron.sql`, `20261018100100_lane2a_rate_limit.sql`,
  `20261018100200_lane2a_teacher_unlock.sql` (2a); `20261018200000_lrn04_review_set.sql`,
  `20261018200100_prc03_attempt_review.sql` (2b). Other lanes use other dates/prefixes.
- pgTAP: `18_expire_cron`, `19_rate_limit`, `20_teacher_unlock` (2a); `21_review_set`,
  `22_attempt_review` (2b). Lanes 1/3 take numbers from 30 up.
- Error codes: `review_needed`, `attempt_not_submitted` (new); `rate_limited` reused.
- Settings keys: `attempt_grace_s`, `practice_stale_h`, `rate_*_per_min`, `review_per_skill`,
  `review_max` — extend `06_settings_seed` test.

## 11. Left to the builder

Exact SQL shape, helper factoring, test fixtures, the admin-role helper name, whether expiry reuses
`private.expire_quiz`. Every file starts from `supabase/templates/` and passes `docs/16` §2.
Update `docs/07` RPC table and §9 in the same PR as the function.
