# Free Topic Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. In this repo, tasks are delegated to Codex via `codex-delegate`; the router reviews and commits.

**Goal:** A signed-in student with no enrolment in a course can open that course's map in preview and complete its free topics end to end (video, notes, practice, homework, quiz, review). Every other topic shows "Activation needed".

**Architecture:** One server rule, "no enrolment row + topic `is_free_preview` ⇒ allowed", lives in `private.practice_access` and a preview-aware `private.topic_states`. `get_course_map(slug)` returns `access: "preview"` instead of raising. The client reads `access` and the new `needs_access` lock reason; it adds a course-page entry and a quiz-result prompt.

**Tech Stack:** Postgres/Supabase migrations + pgTAP; Flutter (Cubit, go_router, supabase_flutter).

**Spec:** `docs/superpowers/specs/2026-11-02-free-topic-preview-design.md`

## Global Constraints

- Every new SQL file starts from `supabase/templates/` (`rpc.sql`, `test.sql`) and passes `docs/16` §2.
- `create or replace` keeps signatures; re-state `grant execute ... to authenticated` on every public RPC you touch. Private helpers keep `revoke ... from public, anon, authenticated`.
- Answer keys never reach the client; grading is untouched.
- Existing enrolled behaviour must not change: every existing pgTAP and Flutter test still passes.
- Error codes come from `docs/07` §9; no new codes (`not_enrolled`, `access_expired` and `topic_locked` are reused).
- Client copy is English and in the teacher's voice:
  - preview banner: "You're previewing this course. Enter an activation code to unlock every topic."
  - locked row: "Activation needed"
  - quiz result action: "Enter activation code"
  - course page action: "Try the free topic"
- Gates:
  - Database: `scripts/db-test.ps1` (CI pgTAP is the source of truth; local `supabase start` can exit 139, see STATUS).
  - Client, from `apps/client`: `dart format .` · `flutter analyze --fatal-infos` · `flutter test -j 2`.

## Review Focus

1. A student **with an expired enrolment** opens a free topic. Expect `access_expired`, not preview (spec rule). Test: `expired enrolment is not preview` in Task 1.
2. **A course with no free topic flagged:** the preview map renders with everything locked (no crash, no empty state). Test: `preview with no free topic` in Task 1 (SQL) and Task 2 (widget).
3. **`get_topic` on a non-free topic by a non-enrolled user** must not return asset titles. Test: `get_topic does not leak locked assets` in Task 1.
4. **A student who activates after previewing:** their free-topic progress (`quiz_passed_at`) carries over, and the next topic opens under the normal rules. Test: `progress carries over after enrolment` in Task 1.
5. A student **enrolled in course A** previews course B. Preview applies per course. Test: `enrolled elsewhere still previews` in Task 1.

---

### Task 1: Server: preview access rule, map, notes, quiz result

**Files:**
- Create: `supabase/migrations/20261105100000_crs06_free_preview.sql`
- Create: `supabase/tests/47_free_preview.test.sql`
- Modify: `docs/07-backend-logic-and-api.md` (the get_course_map, video_playback_grant and start_homework lines, plus §2 lock rules), `docs/06-data-model.md` (topic_states note)

**Interfaces:**
- Produces:
  - `private.topic_states(p_uid uuid, p_course_id uuid)`, same columns. When the user has **no enrolment row** for the course: `status` = `'completed'` if done; else `'open'` if `is_free_preview`; else `'locked'`. A new trailing column `locked_reason text` holds `'needs_access'` or `'previous_quiz'` (null unless locked). Update every reader to read it.
  - `public.get_course_map(p_slug text default null) returns jsonb`.
    - Adds the top-level key `"access": "full" | "preview"`.
    - Each topic's `locked_reason` can now be `"needs_access"`.
    - With a slug and no enrolment, it returns the preview instead of raising `not_enrolled`.
    - Without a slug and no enrolment, it still raises `not_enrolled`.
    - An expired or inactive enrolment still raises `access_expired`.
  - Quiz result JSON (the payload `finish_quiz`/`submit_attempt` returns for quizzes, read by `apps/client/lib/features/quiz/data/models/quiz_model.dart`): adds `"next_needs_access": boolean`. It is true when the user has no enrolment and the next topic is not free.

- [ ] **Step 1: Write the failing pgTAP tests** in `47_free_preview.test.sql`, using `supabase/tests/fixtures` helpers. Cover:
  - `non-enrolled can run free topic loop`:
    - `get_course_map(slug)->>'access' = 'preview'`;
    - `get_practice_questions`, `check_practice_answer`, `start_homework` + `submit_attempt`, `start_quiz` + `submit_attempt` and `get_attempt_review` all succeed on the free topic;
    - `video_playback_grant` passes the access step.
  - `non-free topic refused`: `start_quiz` on a non-free topic raises `not_enrolled`; on the map that topic has `status='locked'` and `locked_reason='needs_access'`.
  - `expired enrolment is not preview`: `get_course_map(slug)` raises `access_expired`, and `practice_access` on the free topic raises `access_expired`.
  - `preview with no free topic`: every topic is `locked` / `needs_access`, and `access='preview'`.
  - `get_topic does not leak locked assets`: a non-enrolled call on a non-free topic raises `not_enrolled`, or returns no assets.
  - `notes readable only for free topic`: the storage `select` policy allows the free topic's notes object, and denies a non-free topic's.
  - `next_needs_access` is true after passing the free topic's quiz with no enrolment, and false/absent when enrolled.
  - `enrolled elsewhere still previews`.
  - `progress carries over after enrolment`: insert an enrolment, and the free topic shows `completed` while the next one is `open`.
  - `slugless map without enrolment still not_enrolled`.
- [ ] **Step 2: Run** `scripts/db-test.ps1`. Expected: 47 fails, all others pass.
- [ ] **Step 3: Write the migration.** Change these:
  - `private.practice_access`: on a missing enrolment row, allow a published `is_free_preview` topic and return its course id; otherwise raise `not_enrolled`.
  - `private.topic_states`: add the preview branch and the `locked_reason` column. `create or replace` cannot change a return type, so drop and recreate it, and recreate its dependents in the same migration.
  - `get_course_map`: add the slug-preview path and the `access` key, and read the reason from `topic_states`.
  - `get_topic`: gate its asset lists through `private.practice_access` (or the same rule).
  - The notes storage read policy: use `public.has_access_topic`.
  - The quiz result builder: add `next_needs_access`.

  Take the latest definitions from the files the research mapped:
  - `20261017100100_prc01_practice.sql:9`
  - `20261017100000_prc01_topic_states.sql:6,72`
  - `20261102100000_p1_homework.sql:476`
  - `20261027100000_l3_notes.sql:17-47`
  - `20261103100300_anl02_quiz_report_skills.sql:53-85`
- [ ] **Step 4: Run** `scripts/db-test.ps1`. Expected: all pass. Then run `scripts/api-private-check.ps1`.
- [ ] **Step 5: Update docs/07 and docs/06** to state the free-preview branch.
- [ ] **Step 6: Commit** (router): `feat(CRS-06): free topic preview for non-enrolled students (server)`.

### Task 2: Client: preview map, course-page entry, quiz prompt

**Files** (all under `apps/client/lib/features/`):
- Modify `course_map/data/models/course_map_model.dart`: parse `access`, plus a new lock reason `NeedsAccess`.
- Modify the `course_map/domain/` entities:
  - `CourseMap.access` is an enum `CourseAccess { full, preview }`.
  - `LockReason` is a sealed class with a new subclass `NeedsAccess`.
- Modify `course_map/presentation/screens/course_map_screen.dart` and `widgets/topic_row.dart`: the banner and the "Activation needed" row, which links to `AppRoutes.activate`.
- Modify `catalogue/presentation/screens/course_page_screen.dart:134`: "Try the free topic" when signed in, not enrolled, and the syllabus has a free topic. It goes to the preview map for that slug.
- Modify `apps/client/lib/core/router/app_router.dart`: a slugged map entry. Use the `/courses` branch with a query parameter `course=<slug>` that the course map screen passes to `getCourseMap(slug:)`. No `Navigator.push`.
- Modify `quiz/data/models/quiz_model.dart` and the quiz result screen: read `next_needs_access`; when true, the primary action is "Enter activation code", going to `AppRoutes.activate`.
- Tests (under `apps/client/test/features/`): `course_map/...`, `catalogue/...` and `quiz/...` model, cubit and widget tests next to the existing ones. Add golden baselines for the preview map (light/dark, 360 and 1280) in the existing golden suite.

**Interfaces:**
- Consumes Task 1's JSON: `access`, `locked_reason: "needs_access"`, `next_needs_access`.

- [ ] **Step 1: Write the failing tests.** All tests carry the `CRS-06:` prefix.
  - Model: `parses access preview`, `parses needs_access lock reason`, and `parses next_needs_access`. Each is also tested with the key absent, defaulting to `full` / `false`.
  - Widget: `preview banner shows copy`, `needs_access row links to activate`, `course page shows Try the free topic only when signed in, not enrolled and a free topic exists`, `quiz result shows Enter activation code when next_needs_access`, and `preview with no free topic renders all locked`.
  - Cubit: the course map cubit loads by slug from the route query.
- [ ] **Step 2: Run** `flutter test -j 2` on those files. Expected: FAIL.
- [ ] **Step 3: Implement** the files above, following ADR-007 layering. Presentation maps the reasons to copy and contains no business logic.
- [ ] **Step 4: Run the gates.** Run `flutter test -j 2 --update-goldens` for the new goldens only. Then run `dart format .`, `flutter analyze --fatal-infos` and `flutter test -j 2`. Expected: all pass.
- [ ] **Step 5: Commit** (router): `feat(CRS-06): free topic preview in the app`.
