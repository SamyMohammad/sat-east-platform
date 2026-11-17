# Student mock exam screens (MCK-01, MCK-02) — Part 3b Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

## Context

The server engine (#89 + hardening #91) is merged and staging-checked: a student can run a two-module adaptive mock through RPCs. The student app still shows a placeholder at `/mock-exams`. **Part 3b builds the student side in Flutter:** the mock hub, the pre-exam screen, the exam (module → end-of-module review → gap → module 2), and a basic finished screen. The full report (S-31) is Part 4.

**Goal:** A student can start, resume and finish a SAT mock from the web app, with the server owning time, routing and score.

**Architecture:** New feature `apps/client/lib/features/mock/` (data / domain / presentation), mirroring `features/quiz` and `features/teacher/mock`. The hub is the shell page at `/mock-exams`; the exam is a top-level route outside the app shell (like the teacher screens), so navigation is hidden during a module. A `MockExamCubit` drives one run through `module → gap → module → finished`, reusing the quiz's answer outbox (`AnswerSaveQueue` / `PendingAnswers`) and the shared `QuestionView` in quiz mode.

**Tech Stack:** Flutter, Cubit, get_it, go_router, `supabase_flutter` RPC via `RpcCaller`. No new packages, no SQL.

**Spec:** `docs/superpowers/specs/2026-11-12-mock-sat-design.md` Part 3 and Part 4 (basic). Server contract: `docs/07-backend-logic-and-api.md` §1.1 (`get_mock_hub`, `start_mock`, `get_mock_session`, `start_mock_module2`, `save_answer`, `submit_attempt`).

## Server contract the client builds against (verified in the merged migrations)

- `get_mock_hub(p_course_id)` → `{passed_topics, forms:[{form_no,k,need,state}], active_group|null}`; `state` ∈ locked / available / in_progress / finished. Works after enrolment expiry while a mock is unfinished.
- `start_mock(p_course_id)`, `get_mock_session(p_group_id)`, `start_mock_module2(p_group_id)` → a **stage**: `{stage:'module', group_id, module_no, attempt_id, title, time_limit_s, deadline, server_now, warn_s, questions:[{id,type,stem_md,choices:[{label,body_md}]}], answers:[{question_id,answer,marked,eliminated}], client_seq}` · `{stage:'gap', group_id, gap_until, server_now}` · `{stage:'finished', group_id, result_id}`. **No `difficulty` in questions.**
- `start_mock` starts the lowest available form or resumes the unfinished one. Errors: `mock_locked`, `mock_none_available`, `not_enrolled`, `access_expired`, `rate_limited`.
- `save_answer(p_attempt_id, p_question_id, p_answer text ≤ 32, p_time_ms, p_marked, p_eliminated text[], p_client_seq)` → `{ok}` / `{ok, stale}`; `deadline_passed` after the deadline + grace; `invalid_input` when the attempt is no longer in progress.
- `submit_attempt(p_attempt_id)` for a mock returns only a stage: `gap` after module 1, `finished` after module 2, or `{stage:'module', group_id, module_no:2}` without questions if module 2 already runs (then call `get_mock_session`).
- Result: no RPC. Read `mock_results` by `result_id` under RLS (`select own`): `route, raw_m1, raw_m2, est_low, est_high` (null possible), `domain_breakdown [{domain,correct,total}]`.

## Global Constraints

- CLAUDE.md A and B: layers presentation → domain → data; domain imports no Flutter/Supabase; Cubits depend on domain interfaces; sealed states + exhaustive `switch`; hand-written JSON as top-level functions; DI only in `lib/core/di/injection.dart`; `go_router` only; `const` where possible; check `isClosed` after every `await`; no controllers or streams created in `build()`.
- The client never decides time, route, score or unlock: it shows what the server returns. When the local clock reaches the deadline the cubit submits; the server finishes the module at `least(now, deadline)` anyway.
- English-only copy in `features/mock/presentation/mock_copy.dart`; never raw exception text; new client error codes `mock_locked`, `mock_none_available`, `mock_settings_invalid` in `core/errors/error_codes.dart` with mapper tests.
- Visuals from `DESIGN.md` and `lib/shared/widgets/` (`AppDialog`, `EmptyState`, `ErrorRetry`, `AppSkeleton`, `AppBanner`, `AppChip`, `LoadingButton`, `ExamBar`). Our own design, nothing copied from College Board (spec).
- Web checked at 360 px and 1280 px. Phone allowed with a banner recommending a laptop or tablet.
- Tests are written first by the implementer (a project hook asks before Claude writes `*_test.dart`). Test names carry requirement IDs (`MCK-01: …`). Fakes: `FakeRpc` for data sources; hand-written fake repository, `InMemoryPendingAnswers`, a broadcast `StreamController<void>` ticker and a mutable clock for the exam cubit (style of `quiz_cubit_test.dart`).
- Gates from `apps/client/`: `dart format .` (then `git status`; revert untouched files), `flutter analyze --fatal-infos`, `flutter test -j 2 --exclude-tags golden`. Run only the new golden cases; 10 old teacher 1280 goldens already fail on this machine (CI excludes `golden`). Clean `failures/` artifacts.
- Do not commit. Never stage `.codex/`, `.impeccable/`, `.vscode/`, `.wrangler/`, `content/`. Commits end with the attribution line from the session reminder.

## Router calls

1. **Course:** the student's SAT course id comes from the student's enrolments (`listMyEnrollments` in `features/auth/data/datasources/auth_remote_data_source.dart`): the active enrolment whose course `code` is `SAT` (extend the select to include `code`). No SAT enrolment → empty state "Mock exams are available with a SAT enrolment". Never "latest enrolment".
2. **Routes:** hub `/mock-exams` stays a shell route (replaces the placeholder). Exam `/mock-exams/run/:groupId` is top-level, outside the shell (no nav during a module), guarded for signed-in students. Leaving the exam page does not stop the clock; the hub then shows Resume (`active_group`).
3. **Entry:** hub "Start" → pre-exam page (rules, banner on phones) → `start_mock` → exam. "Resume" → exam directly via `active_group`.
4. **Gap:** a transition screen with a countdown to `gap_until` (server-time offset) and "Start module 2 now" (calls `start_mock_module2`). When the countdown ends the cubit calls `get_mock_session`, which starts module 2 on the server.
5. **No going back:** no navigation from module 2 to module 1 and no review of module 1 anywhere; the end-of-module review page covers only the running module.
6. **Eliminator:** per-choice strike-through, persisted with the answer (`p_eliminated`) through the outbox. Needs `eliminated` on `PendingAnswer`/`SavedAnswer` — backward-compatible with data already in the Hive box.
7. **Reference sheet:** our own formula sheet (bottom sheet / dialog from the exam bar) with the standard SAT formulas rendered by `MathText`. Calculator slot stays empty until the Desmos decision.
8. **Finished screen (basic):** estimated range (or just the scores when null), route label, correct per module, accuracy per domain, the note "estimate — official scoring uses a different, unpublished model", and a button back to the hub. Question review is Part 4.
9. **Submit button label:** `QuestionView` hard-codes "Submit quiz" (`question_view.dart` ~374, 446, 461): add a `submitLabel` parameter (default unchanged) and pass "Submit module".

## Review Focus

1. **Reload / tab closed mid-module:** hub shows Resume from `active_group`; the exam restores the server's answers overlaid with the outbox; the clock comes from `deadline` and `server_now` offset (Task 3).
2. **Time up during a poor connection:** the cubit flushes the outbox, submits, retries on failure with a visible retry, never loses answers; after `deadline_passed` it falls back to `get_mock_session` (Task 3).
3. **Gap handling:** leaving during the gap and returning later lands on module 2 (already started by the server) or the finished screen, never on module 1 (Task 3).
4. **Hub when the enrolment expired mid-run:** the in-progress form still opens (Task 2).
5. **Result read fails or has null range:** the finished screen shows a retry, or the scores without a range (Task 5).
6. **Double submit / double tap:** one RPC at a time; second tap ignored while `submitting` (Task 3).

---

### Task 0: Setup (router)

- [ ] Worktree `C:/Users/Lenovo/sat-wt-mock3b` on `feat/MCK-01-student-mock` from `origin/main`; copy this plan to `docs/superpowers/plans/2026-11-17-mock-student-screens.md`; commit, push, draft PR `feat(mock): MCK-01 student mock exam screens`.

### Task 1: Data and domain, error codes, outbox `eliminated`

**Files:** create `features/mock/domain/{entities/mock_entities.dart, repositories/mock_repository.dart}`, `features/mock/data/{models/mock_models.dart, datasources/mock_remote_data_source.dart, repositories/mock_repository_impl.dart}`; modify `core/errors/error_codes.dart`, `core/attempts/pending_answers.dart` + `core/attempts/data/hive_pending_answers.dart` + `core/attempts/answer_save_queue.dart` + `core/attempts/attempt_json.dart`, `features/auth/.../auth_remote_data_source.dart` (enrolment `code`). Tests: `test/features/mock/data/…`, `test/core/errors/`, `test/core/attempts/…`.

**Produces (domain):**
- `MockHub(passedTopics, List<MockHubForm> forms, String? activeGroup)`; `MockHubForm(formNo, k, need, MockFormState state)`; `enum MockFormState {locked, available, inProgress, finished}`
- `sealed class MockStage` → `MockModuleStage(MockModule module)`, `MockGapStage(groupId, DateTime gapUntil, DateTime serverNow)`, `MockFinishedStage(groupId, resultId)`; `MockModule(groupId, moduleNo, attemptId, title, timeLimitS, DateTime deadline, DateTime serverNow, warnS, List<AttemptQuestion> questions, List<SavedAnswer> answers, clientSeq)` — reuse `AttemptQuestion`/`AttemptChoice`/`SavedAnswer` from `core/attempts`; the mock question has no difficulty, so parse with a mock-specific function, do not touch `quizSessionFromJson`.
- `MockResult(id, route, rawM1, rawM2, int? estLow, int? estHigh, List<DomainScore> domains)`; `DomainScore(domain, correct, total)`
- `abstract interface class MockRepository`: `Future<Result<String?>> satCourseId()`; `hub(courseId)`; `start(courseId)`; `session(groupId)`; `startModule2(groupId)`; `save({attemptId, questionId, answer, timeMs, marked, eliminated, clientSeq})`; `submit(attemptId)` → `Result<MockStage>`; `result(resultId)` → `Result<MockResult>`.
- `SavedAnswer` and `PendingAnswer` gain `Set<String> eliminated` (default empty); the Hive record reads a missing field as empty.
- Error codes `mockLocked`, `mockNoneAvailable`, `mockSettingsInvalid` (constants + `isServerCode`).

- [ ] **Step 1: Failing tests:** mapper cases for the three codes; `FakeRpc` tests for each repository method (exact RPC names and param maps per the contract above, `p_eliminated` sent as a list); parse fixtures for the three stage shapes, a hub with all four states and `active_group`, a result with null `est_*`; a module whose `answers` carry `eliminated`; malformed payloads → `Failure(internal)`; `PendingAnswer` round trip with and without `eliminated`, and a record stored in the OLD shape still loads (Hive compatibility test); `AnswerSaveQueue` passes `eliminated` to the save callback.
- [ ] **Steps 2–5:** run red, implement, gates, report.

### Task 2: Hub page and pre-exam page

**Files:** `presentation/cubit/mock_hub_{cubit,state}.dart`, `presentation/screens/{mock_hub_screen,mock_pre_exam_screen}.dart`, `presentation/widgets/`, `presentation/mock_copy.dart`; `app_router.dart` (replace the placeholder for `AppShellDestination.mockExams`; add the pre-exam route); DI. Tests under `test/features/mock/presentation/`.

**Produces:** `sealed class MockHubState` → `MockHubLoading`, `MockHubNoCourse`, `MockHubLoaded(courseId, MockHub hub, {busy, AppError? lastError})`, `MockHubFailed(AppError)`; `MockHubCubit(MockRepository)` with `load()`, `start()` → `Future<MockStage?>` (calls `start_mock`, returns the stage so the screen navigates to `/mock-exams/run/:groupId`).
- Hub: one card per form — locked ("Pass N topics to unlock", with `passed_topics`), available (Start), in progress (Resume), finished (Finished + the range when known is NOT shown here; Part 4). Resume shown for `active_group` even when the enrolment expired.
- Pre-exam: what to expect (2 modules, 22 questions and 35 minutes each, timer does not pause, no going back, 2-minute break from the setting is not mentioned numerically), phone banner (`AppBanner` warning) below the web wide breakpoint, "Start module 1" (`LoadingButton`).
- Copy for `mock_locked`, `mock_none_available`, `not_enrolled`, `access_expired`, `rate_limited`, default.

- [ ] **Step 1: Failing tests:** cubit — SAT course among `[EST, SAT]`, none → NoCourse and no hub call, load failure, start success returns the stage, `mock_locked`/`access_expired` → `lastError`, double start ignored while busy; widgets — the four form states, Resume for `active_group`, phone banner at 360, student redirected correctly in `app_router_test`.
- [ ] **Steps 2–4:** red, implement, gates. **Step 5:** goldens hub (loaded; light/dark 360/1280) and pre-exam (360/1280). Report.

### Task 3: Exam cubit

**Consumes:** Task 1. **Files:** `presentation/cubit/mock_exam_{cubit,state}.dart`, `presentation/mock_attempt_clock.dart` (generalise `QuizAttemptClock` only if a tiny shared interface works, otherwise a small mock-specific clock copied with the same offset logic — no edits to quiz behaviour); DI factory `registerFactoryParam<MockExamCubit, String /*groupId*/, void>`.

**Produces:** `sealed class MockExamState` → `MockExamLoading`, `MockExamFailed(AppError)`, `MockExamModule(module, index, answers, marked, eliminated, remaining, timerHidden, reviewOpen, submitting, saveError, submitError)`, `MockExamGap(groupId, gapUntil, remaining, startingModule2)`, `MockExamFinished(MockResult? result, AppError? resultError)`.
- `MockExamCubit(MockRepository, now, ticker, PendingAnswers)`: `start()` (resume via `session(groupId)`, overlay outbox), `select(label)`, `sprChanged(text)`, `toggleMark()`, `toggleEliminate(label)`, `goTo(i)`, `next()`, `prev()`, `toggleTimer()`, `openReview()`/`closeReview()`, `submitModule()`, `timeUp()`, `startModule2()`, `retryResult()`.
- Save path = the quiz's: write to the outbox first, `AnswerSaveQueue` sends with the next `client_seq`, acknowledged by rev. `submitModule()` flushes the queue, then `submit(attemptId)`; stage `gap` → `MockExamGap`; `finished` → load the result; `{stage:'module'}` without questions → `session(groupId)`. `deadline_passed` or `invalid_input` on save/submit → `session(groupId)` and render whatever the server says. Gap: the ticker counts down to `gapUntil`; at zero `session(groupId)` (the server starts module 2); `startModule2()` calls `start_mock_module2`. 5-minute warning shown when `remaining <= warnS`.

- [ ] **Step 1: Failing tests** (fake ticker, mutable clock, `InMemoryPendingAnswers`): resume merges outbox over server answers; select/spr/mark/eliminate save through the queue with increasing `client_seq` and the right payload; time up → one submit, outbox flushed first; submit failure → `submitError`, retry succeeds, no second submit while `submitting`; module 1 submit → Gap with the countdown; countdown end → `session` called once → module 2; `startModule2()` early; leaving and re-`start()` during gap lands on module 2; `submit` returning `finished` loads the result, a result read failure → `resultError` + `retryResult()`; `deadline_passed` → state follows `session()`; clock offset from `server_now`; `isClosed` after awaits (dispose mid-flight).
- [ ] **Steps 2–5:** red, implement, gates, report.

### Task 4: Exam screens

**Consumes:** Task 3, `QuestionView` quiz mode, `ExamBar`, `ExamWarningBanner`. **Files:** `presentation/screens/mock_exam_screen.dart`, `presentation/widgets/{mock_module_view, mock_review_page, mock_gap_view, mock_reference_sheet}.dart`; `question_view.dart` + `question_view_mode.dart` (`submitLabel`); `app_router.dart` (route `/mock-exams/run/:groupId` outside the shell); `lib/shared/widgets/question_view/parts/` only if the eliminator needs wiring.

- Module view: `QuestionView` in `QuizMode` (title "Module N", index/total, remaining, `warnAt = warn_s`, timer Hide/Show, navigator with answered/marked, mark for review), choice eliminator (strike-through, dashed border per DESIGN.md) wired to `toggleEliminate`, "Reference" button opening `MockReferenceSheet` (own formulas via `MathText`: area and volume formulas, circle, Pythagorean theorem, special right triangles, degrees/radians, arc and sector; written by us). Calculator button absent.
- End-of-module review page (before submit): grid of questions with answered / unanswered / marked, tap to jump, "Submit module N" with a confirm `AppDialog` naming unanswered count.
- Gap view: "Module 1 submitted", countdown, "Start module 2 now"; no score, no route.
- Exit: browser back / "Leave" from the exam is allowed, with a one-line notice that the clock keeps running (a `PopScope`/dialog). Finished state navigates to the finished screen (Task 5).
- `submitLabel` default keeps "Submit quiz"; existing quiz goldens stay byte-identical.

- [ ] **Step 1: Failing widget tests:** timer and warning banner at `warn_s`; eliminate toggles a choice and calls the cubit; reference sheet opens and closes; review page counts and jumps; submit confirm names unanswered questions; gap view has no score text; leave dialog; the app shell is not rendered on the run route; quiz screen still says "Submit quiz".
- [ ] **Steps 2–4:** red, implement, gates. **Step 5:** goldens: module view (MCQ with an eliminated choice, SPR), review page, gap view, reference sheet, warning state — light/dark 360/1280 where meaningful; confirm no existing `qv_quiz_*` baseline changes. Report.

### Task 5: Finished screen, docs, review, PR (router)

- [ ] `presentation/screens/mock_finished_screen.dart` (+ widgets) per Router call 8; tests (null range, read failure retry, domain table); goldens 360/1280.
- [ ] Docs: `docs/04` S-27/S-28/S-29 rows (what exists), `docs/STATUS.md` lane A.
- [ ] Gates myself; `/flutter-code-quality:review-gate`; `/flutter-code-review`; `code-reviewer` on the branch (focus: timer/clock, outbox + `eliminated` Hive compatibility, double submit, gap logic, leaks); fixes through the implementer; CI green; mark ready; tell the owner.
- [ ] After merge and deploy, **staging check in Chrome (owner's browser is signed in):** (1) teacher: assemble and publish a form (permanent — there is no unpublish); (2) as the student account fake 3 passed topics and an active SAT enrolment through the SQL editor, take module 1 quickly (answer 2–3 questions, submit), watch the gap and module 2, finish, see the result; (3) **cleanup, with the owner's OK:** delete the test mock rows (`mock_results`, mock attempts and their answers, the published form and its questions' exposure rows) and revert roles, topic progress and enrolment to what they were; verify with selects.

## Verification

- `flutter analyze --fatal-infos` clean; `flutter test -j 2 --exclude-tags golden` green; new goldens reviewed visually; CI green.
- Staging flow above, including the cleanup and role verification.

## Out of scope

Part 4 (question-by-question report, `get_attempt_review` for mocks, per-skill breakdown, drill set), Desmos calculator, EST mock, mobile builds, scale-table calibration, the `skills` page counting mock questions.
