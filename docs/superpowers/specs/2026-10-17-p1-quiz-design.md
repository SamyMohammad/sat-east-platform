# P1 slice part 5 — Quiz + unlock — design

Status: approved 2026-10-17. Parent: [`2026-10-16-p1-slice-demo-seed-design.md`](2026-10-16-p1-slice-demo-seed-design.md) (slice overview, part 5). Story: `docs/03` L-6. Reqs: PRC-03 (no spiral / blueprint yet), PRC-04, PRC-05 (quiz autosave + resume), LRN-01 (practice → quiz gate; video, notes, homework not in the slice), LRN-02 (practice + quiz rules), LRN-03 (pass unlocks next), LRN-04 (cooldown only). Screens: `docs/04` S-15 (topic page, slice version), S-22 (quiz player), S-21 (result, score only).
Tier **L** (`docs/15` §2): grading, scoring, unlocking → this spec, pgTAP, `/security-review`.

## Goal
On staging, the slice works end to end: an enrolled student opens a topic, practises 10 questions, takes the timed quiz, and on a pass (≥ `pass_mark`) the next topic opens on the course map. The server owns the clock, the grading, the score and the unlock. A closed tab resumes the quiz with saved answers; time-up submits it.

## Scope (agreed 2026-10-17)
- **In:** a topic page with Practice and Quiz; quiz gate on `practice_count ≥ practice_min`; RPCs `get_topic`, `start_quiz`, `save_answer`, `submit_attempt`; a shared private grader; quiz player (existing `QuestionView` quiz mode); result page; 12-hour retake cooldown; the part-4 hardening (advisory lock on the distinct practice count, pool/status re-check in `check_practice_answer`).
- **Out:** spiral questions and the difficulty mix (PRC-03 blueprint), answer-by-answer review after submit (S-21 review list, `get_attempt_review`), the targeted review set after a fail (LRN-04), the `cron-expire-attempts` job (replaced in the slice by lazy expiry, §1.5), video / notes / homework steps, teacher unlock UI.
- **Anti-goals:** any key, explanation or per-question correctness before submit; the client sending a score, a pass flag or a timer value the server trusts; a pass that does not open the next topic.

## 1. Backend
New migrations from `supabase/templates/`, `docs/16` §2 checklist. Every public RPC: `security definer`, `set search_path = ''`, `auth.uid()` first, `revoke … from public, anon`, `grant execute … to authenticated`. Private helpers revoked from `public, anon, authenticated`.

### 1.1 Settings (new rows, `on conflict do nothing`)
`quiz_size` = 12 · `quiz_time_per_q_s` = 90 · `quiz_warn_s` = 300. Existing: `pass_mark` 75, `cooldown_h` 12, `practice_min` 10, `save_grace_s` 30.

### 1.2 Shared grader — `private.grade_answer(p_question_id uuid, p_answer text) returns boolean`
MCQ: `upper(btrim(p_answer)) = correct_answer->>'choice'`; SPR: `private.grade_spr(btrim(p_answer), correct_answer)`. Null or empty answer → `false`. Missing key → `invalid_key`. `check_practice_answer` is re-created to call it (behaviour unchanged; `16_practice` stays green unchanged).

### 1.3 Part-4 hardening in `check_practice_answer`
- Before the distinct-count check: `perform pg_advisory_xact_lock(hashtextextended(v_uid::text || p_question_id::text, 0))`.
- The question load also requires `pool = 'practice' and status = 'published'`, else `invalid_input`.
- Test: a question moved out of the practice pool after the draw → `invalid_input`.

### 1.4 Quiz state for a topic — `private.quiz_state(p_uid, p_topic_id) returns jsonb`
Used by `get_topic` and `start_quiz`. Access as in practice (`private.practice_access`: published, enrolled, active, not locked). Then, in order:
| `state` | Rule |
|---|---|
| `in_progress` | an `attempts` row `kind='quiz'`, this topic, `in_progress`, deadline + `save_grace_s` not passed (carries `attempt_id`) |
| `practice_needed` | `practice_count < practice_min` (carries `practice_count`, `practice_min`) |
| `cooldown` | `quiz_last_failed_at + cooldown_h > now()` (carries `available_at`) |
| `available` | otherwise |
Always also carries `best_score_pct` (`quiz_best_score` or null) and `passed` (`quiz_passed_at is not null`). A completed (passed) topic may be re-taken; a retake never removes the pass.

### 1.5 Lazy expiry — `private.expire_quiz(p_attempt_id)`
An in-progress quiz whose `deadline + save_grace_s` has passed is graded and submitted exactly as `submit_attempt` does (§1.8), with `submitted_at = deadline`. Called by `get_topic`, `start_quiz`, `save_answer` and `submit_attempt` for the caller's quiz attempts of that topic **before the access check** (*Claude's call*). Grading an overdue attempt needs no access, and it is stamped at the deadline, so the score is the same whenever it runs. **Limit (ruling during build):** when the same call then raises `access_expired` / `not_enrolled` / `topic_locked`, Postgres rolls the expiry back with it; such an attempt stays `in_progress` until the student's next successful call (access restored) or the future `cron-expire-attempts`, and is then graded at its deadline with the same result. (`cron-expire-attempts` replaces it later.)

**Access on in-quiz calls (*Claude's call*):** `save_answer` and a manual `submit_attempt` run expiry first, then the practice access check (`access_expired` / `not_enrolled` / `topic_locked` stop them) — consistent with "no access, no course". A quiz cut off this way is graded by lazy expiry at its deadline.

### 1.6 `public.get_topic(p_topic_id uuid) → jsonb`
`{ "id", "title", "slug", "sort_label", "status": "open|completed", "practice": {"count", "min"}, "quiz": <quiz_state> }`. `locked` topic → `topic_locked`. `sort_label` from `private.topic_states`.

### 1.7 `public.start_quiz(p_topic_id uuid) → jsonb`
- Runs §1.5, then `quiz_state`: `in_progress` → **resume** that attempt; `practice_needed` → `practice_needed` error *(new code)*; `cooldown` → `cooldown_active`; `available` → create.
- Create: `attempts(kind='quiz', topic_id, course_id, status 'in_progress', started_at = now(), time_limit_s = quiz_size_drawn * quiz_time_per_q_s)`. Draw `quiz_size` from `pool='quiz' and status='published'` of the topic, never-seen-by-user first (`question_exposure`), then `random()`. Fewer than `quiz_size` → take what there is; zero → `pool_exhausted`. Insert `attempt_questions` 1..n and `question_exposure`.
- Deadline = `started_at + time_limit_s`.
- Returns (resume and create alike):
```json
{ "attempt_id", "title": "<sort_label> <topic title>", "time_limit_s", "deadline", "server_now", "warn_s",
  "questions": [ {"id","type","difficulty","stem_md","choices":[{"label","body_md"}]} ],
  "answers":   [ {"question_id","answer": "B"|null, "marked": bool} ],
  "client_seq": <max saved client_seq or 0> }
```
No keys, explanations, hints, misconceptions, or `is_correct`.

### 1.8 `public.save_answer(p_attempt_id uuid, p_question_id uuid, p_answer text, p_time_ms int, p_marked boolean, p_eliminated text[], p_client_seq int) → jsonb`
Full `docs/07` §1 signature now (*Claude's call*), so homework and mock reuse it without a breaking change.
- Attempt: caller's, `kind='quiz'`, `in_progress`, contains the question → else `invalid_input`; §1.5 first; after `deadline + save_grace_s` → `deadline_passed`.
- `p_answer` null clears the answer; > 32 chars → `invalid_input`.
- Upsert `attempt_answers(answer = {"value": p_answer}, time_ms = clamp(p_time_ms, 0, 3600000) (total time on the question so far, client-measured), marked_for_review, eliminated = to_jsonb(p_eliminated), client_seq, answered_at)`; a call whose `p_client_seq` ≤ the stored one is ignored (returns `{"ok": true, "stale": true}`). `is_correct` stays null until submit. Returns `{"ok": true}`.
- The client measures time per question (time the question is on screen, summed across visits) from its injected clock; the server only clamps and stores it (PRC-04).

### 1.9 `public.submit_attempt(p_attempt_id uuid) → jsonb`
- Attempt: caller's, `kind='quiz'` (other kinds → `invalid_input` for now). Already `submitted` → return the stored report (idempotent).
- Grade every `attempt_questions` row with `private.grade_answer` (unanswered = wrong); write `attempt_answers.is_correct`; `score_raw` = correct, `score_total` = n, `score_pct = round(100 * raw / total, 2)`; `status='submitted'`, `submitted_at = least(now(), deadline)`.
- `passed = score_pct >= pass_mark`. `topic_progress` upsert: `quiz_best_score = greatest(existing, score_pct)`; pass → `quiz_passed_at = coalesce(quiz_passed_at, now())`; fail → `quiz_last_failed_at = now()` (a fail never clears a pass).
- Unlock needs no extra write: `private.topic_states` already opens the next topic when this one is completed (`docs/07` §2). `compute_unlocks` is not built.
- Report: `{ "score_raw", "score_total", "score_pct", "pass_mark", "passed", "next_topic": {"id","title"} | null, "retake_at": <timestamp> | null }` — `next_topic` = the next topic in course order when it is now open; `retake_at` set on a fail. No keys (review list is out of scope).

### 1.10 Error codes
Existing: `not_authenticated`, `invalid_input`, `not_enrolled`, `access_expired`, `topic_locked`, `pool_exhausted`, `cooldown_active`, `deadline_passed`. **New:** `practice_needed` — added to `docs/07` §9 and the client's `ErrorCodes`.

### 1.11 Tests — `supabase/tests/17_quiz.test.sql`
anon 42501 on all four; not_authenticated; topic_locked; `practice_needed` below `practice_min`; available at `practice_min`; `cooldown_active` inside `cooldown_h`, available after; start draws `quiz_size` from the quiz pool only (no practice/draft questions), unseen first; payload has no `correct_answer`/`explanation`/`hint`/`misconception`/`is_correct` keys; start twice → same attempt (resume) with saved answers and max `client_seq`; save stale `client_seq` ignored; save after deadline + grace → `deadline_passed`; submit grades MCQ + SPR (equivalent form), unanswered wrong; score and pass at exactly `pass_mark`; pass → `quiz_passed_at` set and next topic `open` in `get_course_map`, `next_topic` returned; fail → `quiz_last_failed_at`, `retake_at`, next topic still `locked`; fail after a pass keeps the pass; submit twice → same report; another user's attempt → `invalid_input`; lazy expiry: a started attempt moved past its deadline is submitted by the next `get_topic`/`start_quiz` with answers saved before the deadline (with access; without access the call raises and nothing persists); part-4 hardening test (§1.3); `15_course_map` and `16_practice` unchanged and green.

## 2. Client

### 2.1 Topic page — `lib/features/topic/`
- Route `/courses/topics/:topicId` → `TopicScreen` (replaces practice at that path). Practice moves to `/courses/topics/:topicId/practice`, quiz to `/courses/topics/:topicId/quiz`, result to `/courses/topics/:topicId/quiz/result` (report passed as `extra`; a cold deep link to result goes back to the topic page).
- Shows `sort_label` + title, a Practice card ("Practice" · "<count> of <min> practice questions done"), and a Quiz card whose button follows `quiz.state`: `available` → "Start quiz"; `in_progress` → "Resume quiz"; `practice_needed` → disabled, "Answer <min − count> more practice questions to unlock the quiz."; `cooldown` → disabled, "You can retake the quiz after <local time>."; plus "Best score <n>%" and a "Passed" badge when present.
- `TopicCubit(TopicRepository)`: `load(topicId)`, refreshed when the page is shown again (returning from practice or a quiz).
- The course-map row and Continue card navigate to the topic page; the practice summary's "Back to course" stays, and a new "Back to topic" is added.

### 2.2 Quiz — `lib/features/quiz/`
- `QuizCubit(QuizRepository, DateTime Function() now, Ticker)`: `start(topicId)`, `select`, `sprChanged`, `toggleMark`, `goTo(index)`, `next`, `prev`, `submit()`, `timeUp()`.
- **Clock:** offset = `server_now − now()` at start; `remaining = deadline − (now() + offset)`, ticked every second by an injected ticker (cancelled in `close()`). At `remaining ≤ 0` the cubit submits once and shows the existing `quiz_time_up_dialog`.
- **Autosave:** every answer or mark change → `save_answer` with `client_seq + 1`, sent in order (one in flight, latest wins); failures retry with backoff and surface a small "Not saved — retrying" note; `deadline_passed` → submit. Submit waits for the in-flight save.
- **QuestionView:** `QuizMode(title, index, total, remaining, timeBudget = time_limit_s, warnAt = warn_s, answered, marked)`; navigator via `onJumpTo`; `onSubmit` opens the existing confirm flow; `onToggleTimer` hides the timer locally. No feedback during the quiz.
- **Result page:** "Quiz passed" / "Quiz not passed", "<raw> of <total> correct · <pct>%", "Pass mark <pass_mark>%"; passed → "Next topic" (to `next_topic`'s topic page) when present, else "Back to course"; failed → "You can retake it after <local time>." + "Back to topic".
- **Errors:** `practice_needed`, `cooldown_active`, `topic_locked`, `access_expired`, `not_enrolled`, `pool_exhausted`, network → copy + back; reuse `lib/core/presentation/learning_copy.dart` where it fits.

### 2.3 Tests
Cubit tests: start (create + resume restores answers, marks, index 0), each error, autosave ordering and stale handling, save retry, timer countdown with a fake ticker and offset, time-up submits exactly once, manual submit after pending save, result mapping. Widget tests: topic page for each quiz state; quiz screen timer/warning/navigator wiring; result page passed/failed; 360 and 1280 px. Router: new paths and cold deep links.

## 3. Done when
- CI green (pgTAP 15/16/17, analyze, tests); `/security-review`.
- **Staging check (the slice exit):** enrolled demo student → 1.1 topic page: Quiz disabled → 10 practice questions → Quiz enabled → start, answer some, reload the tab → resumes with answers and the timer still counting → submit: ≥ 9/12 (75%) passes → course map shows 1.1 completed and 1.2 open; a failing attempt shows the retake time and 1.2 stays locked. 360 and 1280 px.
- `docs/07` (§1 rows, §9 `practice_needed`), `docs/STATUS.md` (slice done; deferred list).

### Repeat questions (decided by the user 2026-10-17)
The demo seed has 12 quiz questions per topic and `quiz_size` is 12, so every retake shows the same questions in a new order. Accepted for the slice (demo content); `docs/07` §3 "never repeat" holds once real pools are larger than `quiz_size`. The pgTAP unseen-first case uses a fixture pool larger than `quiz_size`. Noted in STATUS.

## 4. Calls made by Claude (check these)
- Names: `start_quiz` (not generic `start_attempt`), generic `save_answer` and `submit_attempt` (quiz-only for now).
- New settings `quiz_size` 12, `quiz_time_per_q_s` 90, `quiz_warn_s` 300; new error code `practice_needed`.
- Topic page sits between the map and practice/quiz; the quiz gate is practice only (homework is not in the slice).
- Lazy expiry instead of the cron job; a submit after the deadline is stamped at the deadline.
- `save_answer` takes the full `docs/07` signature (`time_ms`, `eliminated`) now.
- Overdue quizzes are graded before any access check; in-quiz saves/submits still require access.
- Retakes allowed after a pass; best score kept; a fail never removes a pass.
- Result shows score only; answer review later.

## 5. Deferred (STATUS Open)
Quiz repeats on the 12-question demo pools; spiral + difficulty blueprint; answer review (`get_attempt_review`); targeted review set; `cron-expire-attempts`; rate limiting.
