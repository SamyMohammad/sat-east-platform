# P1 slice part 4 — Practice — design

Status: draft 2026-10-17 (awaiting approval). Parent: [`2026-10-16-p1-slice-demo-seed-design.md`](2026-10-16-p1-slice-demo-seed-design.md) (slice overview, part 4). Story: `docs/03` L-4 (slice subset). Reqs: PRC-01 (no filters yet), PRC-04 (time per question), LRN-02 (practice count). Screens: `docs/04` S-19 (practice question player). Contract: `docs/07` §1 (`get_practice_questions`, `check_practice_answer`) and the reveal rule in [`2026-10-14-f4-questionview-design.md`](2026-10-14-f4-questionview-design.md) §6.
Tier **L** (`docs/15` §2): grading and access → this spec, pgTAP, `/security-review`.

## Goal
From the course map, a student taps an open topic and practises it: questions one at a time in the shared `QuestionView` (practice mode). A wrong first answer shows a hint (and the misconception note for that choice when there is one) and allows one more try; a second miss reveals the key and explanation; a correct answer shows the explanation. Every answer is graded on the server and logged, and the topic's `practice_count` grows. Keys never reach the client before the student has answered correctly or missed twice. This unblocks quiz + unlock (part 5).

## Scope (agreed 2026-10-17)
- **In:** RPCs `get_practice_questions` and `check_practice_answer`; a private helper that computes topic lock state (shared with `get_course_map`); client feature `practice` replacing the topic stub; a short end-of-set summary.
- **Out:** subtopic/difficulty filters and the practice setup screen (S-18), Ask AI, "watch the explanation" video, report-a-question, mistake notebook, the video → notes steps before practice (in this slice practice is open for every open topic), images in stems (demo has none; `figureBuilder` stays unset), rate limiting (see §5).
- **Anti-goals:** a key, explanation or misconception map in any response before it is earned; the client deciding correctness, lock state or counts; trusting a client-sent `reveal` on its own.

## 1. Backend

New migration from `supabase/templates/rpc.sql`, `docs/16` §2 checklist. Both RPCs: `security definer`, `set search_path = ''`, `auth.uid()` check first, `revoke … from public, anon`, `grant execute … to authenticated`.

### 1.1 Shared lock state — `private.topic_states(p_uid uuid, p_course_id uuid)`
Returns one row per published topic: `topic_id, unit_id, unit_title, title, slug, is_free_preview, pos, unit_no, topic_no, status, after_title` — exactly the CTE that `get_course_map` uses today. `get_course_map` is re-created (same signature, same output) to read from it, so the rule lives in one place. Revoked from `public, anon, authenticated`. The existing `15_course_map` pgTAP must stay green unchanged — that is the regression guard.

### 1.2 Topic access (both RPCs)
For the question's / given topic: topic must exist and be published (`invalid_input`); caller enrolment for its course: none → `not_enrolled`, not active or expired → `access_expired` (same rules as `get_course_map`); status from `private.topic_states` = `locked` → `topic_locked`. `completed` and `open` topics may be practised.

### 1.3 `public.get_practice_questions(p_topic_id uuid) → jsonb`
- Access per §1.2.
- Creates a new `attempts` row: `kind = 'practice'`, `user_id`, `course_id`, `topic_id`, `status = 'in_progress'`.
- Draws `settings.practice_min` (10) questions from the topic: `pool = 'practice'`, `status = 'published'`; order: never-seen by this user first (no `question_exposure` row), then `random()`. Fewer available → returns what there is; zero → `pool_exhausted`.
- Inserts `attempt_questions` (positions 1..n) and upserts `question_exposure` (`on conflict do nothing`).
- Returns:
```json
{ "attempt_id": "…", "rep_target": 10,
  "questions": [ { "id": "…", "type": "mcq|spr", "difficulty": "E|M|H",
                   "stem_md": "…", "choices": [ {"label":"A","body_md":"…"} ] } ] }
```
`choices` is `[]` for SPR. **No** key, explanation, hint or misconceptions. `rep_target` = number of questions returned.

### 1.4 `public.check_practice_answer(p_attempt_id uuid, p_question_id uuid, p_answer text, p_time_ms int, p_reveal boolean default false) → jsonb`
Signature change vs `docs/07` §1: adds `p_attempt_id` (the answer is logged against the practice attempt; `attempt_answers` is keyed by attempt + question). `docs/07` is updated.
- Attempt must belong to the caller, be `kind = 'practice'`, `status = 'in_progress'`, and contain the question → else `invalid_input`. Access per §1.2 re-checked (enrolment may have expired, topic re-locked).
- `p_answer`: MCQ = choice label (`A`–`D`), SPR = the raw typed string. Empty/oversized (> 32 chars) → `invalid_input`. `p_time_ms` clamped to `0..3_600_000`.
- Grading: MCQ → `upper(p_answer) = key.correct_answer->>'choice'`; SPR → `private.grade_spr(p_answer, key.correct_answer)` (GRD-02). A malformed SPR answer is simply wrong (catch the parse error → `false`); a malformed key raises `invalid_key` as today.
- Try number = existing `attempt_answers` row for (attempt, question)? 2 : 1. A **third** check on the same question → `invalid_input` (the UI never sends one).
- Logging: try 1 inserts `attempt_answers(answer = {"value": p_answer}, is_correct, time_ms, answered_at)`; try 2 updates `answer`, `is_correct`, adds `time_ms`. `topic_progress.practice_count += 1` on try 1 only (upsert the `topic_progress` row). Never updates `quiz_*`, `unlocked_at`, or attempt status.
- **Reveal is server-checked:** the key + explanation are returned when `is_correct`, or when `p_reveal = true` **and** this is try 2 **and** try 1 was wrong. A `p_reveal = true` on try 1 is ignored.
- Response:
  - correct: `{ "is_correct": true, "key": …, "explanation_md": "…" }`
  - wrong, not revealed: `{ "is_correct": false, "hint_md": questions.hint_md, "misconception_md": misconceptions->>upper(answer) or null }`
  - wrong, revealed: `{ "is_correct": false, "key": …, "explanation_md": "…" }`
  - `key` = `{"choice":"B"}` for MCQ, `{"text": accepted[0]}` for SPR (the first accepted form is the canonical display).
- Attempt stays `in_progress`; it is never submitted (practice has no end). Abandoned practice attempts are harmless; cleaning them is out of scope.

### 1.5 Tests (`supabase/tests/16_practice.test.sql`)
anon → 42501; not authenticated; `not_enrolled`; `access_expired`; locked topic → `topic_locked` (both RPCs); payload has no `correct_answer` / `explanation` / `hint` / `misconceptions` keys anywhere (`docs/12` §2 style); unseen-first draw (pre-seed exposure for some questions); size = `practice_min` and smaller pool; `pool_exhausted`; MCQ correct → key + explanation, `practice_count` 1; MCQ wrong → hint + misconception, no key; second wrong with reveal → key; reveal on try 1 → no key; third check → `invalid_input`; SPR equivalent forms graded correct (`1/2` vs `.5`), malformed SPR → wrong not error; other user's attempt → `invalid_input`; `practice_count` counts try 1 only; `get_course_map` output unchanged (existing file).

## 2. Client — `lib/features/practice/` (ADR-007 §4)
```
data/   datasources/practice_remote_data_source.dart (RpcCaller), models/ (hand-written fromJson), repositories/
domain/ entities: PracticeSet(attemptId, repTarget, questions: List<PracticeQuestion>),
        PracticeQuestion(id, kind mcq|spr, difficulty, stemMd, choices),
        CheckResult sealed: Correct(key, explanationMd) | Miss(hintMd, misconceptionMd) | Revealed(key, explanationMd)
        repositories/practice_repository.dart → Result<T>
presentation/ cubit/practice_cubit.dart + state, screens/practice_screen.dart, practice_copy.dart
```
- Cubit (`PracticeCubit(PracticeRepository, Clock)`): `start(topicId)`, `select(label)`, `sprChanged(text)`, `check()`, `next()`, `practiceMore()`. It tracks the try number per question and sends `reveal = true` on the 2nd check after a miss. Time per question from the injected clock (from question shown to check). `isClosed` checks after awaits.
- State → `QuestionView`: `QuestionData` from `PracticeQuestion`; `PracticeMode(feedback, rep: index + 1, repTarget)`; feedback mapping: before check `Idle`, in flight `Checking`, `Miss` → `FirstMiss(missed, hintMd, noteMd: misconceptionMd)`, `Correct` → `Correct(explanationMd, firstTry: <first wrong answer if any>)`, `Revealed` → `Revealed(key, firstTry, explanationMd)`.
- **End of set:** after the last question's Next → summary: "Practice complete", "You got X of N right on the first try." with **Practice more** (new set via `get_practice_questions`) and **Back to course**.
- **Errors:** start fails → `topic_locked` "This topic is locked. Pass the previous quiz first." / `access_expired` / `not_enrolled` (reuse course-map copy) / `pool_exhausted` "No practice questions yet." / network → retry. A failed `check` keeps the answer and feedback state, shows "Couldn't check your answer. Try again." and lets the student press Check again (same try number — the server only counts a try that reached it).
- **Routing:** `/courses/topics/:topicId` now builds `PracticeScreen(topicId, title from extra ?? 'Practice')`; `TopicStubScreen` is deleted. Back returns to the course map.
- DI: data source + repo lazy singletons, cubit factory; `Clock` from `lib/core` if one exists, else a tiny `Clock` interface there.

## 3. Done when
- pgTAP (new file + unchanged `15_course_map`), `flutter analyze --fatal-infos`, `flutter test` green in CI; `/security-review`.
- Cubit tests: start success/each error; correct first try; miss → retry correct; miss → miss → revealed (asserts `reveal = true` sent only on the 2nd check); check network failure then retry; next / end-of-set summary; practice more; time measured from the injected clock.
- Widget tests: practice screen wiring for each feedback state and the summary, 360 and 1280 px.
- **Staging check:** enrolled demo student → course map → 1.1 Linear Equations → 10 questions; one MCQ wrong twice (hint, then key), one SPR answered in an equivalent form, summary shows; 1.2 still locked and its URL typed directly shows "This topic is locked."
- `docs/07` §1 rows updated (signature, response), `docs/STATUS.md` updated.

## 4. Calls made by Claude (check these)
- `check_practice_answer` takes `attempt_id` (docs/07 changes).
- Server enforces "reveal only after a recorded miss"; a third check is rejected.
- Set size = `practice_min` (10); no new setting.
- `practice_count` counts questions attempted (first try), across sets — practice is unlimited.
- Lock logic moved into `private.topic_states` and `get_course_map` reads it.
- SPR key shown as the first accepted form.
- Practice opens directly for any open or completed topic (video/notes steps not in the slice).

## 5. Deferred (STATUS Open)
- Rate limiting (`private.hit_rate_limit` from `docs/16` is specified but not built) for both practice RPCs.
- Cleanup of abandoned in-progress practice attempts.
