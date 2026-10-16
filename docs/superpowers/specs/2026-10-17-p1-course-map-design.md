# P1 slice part 3 — Course map — design

Status: draft 2026-10-17 (awaiting approval). Parent: [`2026-10-16-p1-slice-demo-seed-design.md`](2026-10-16-p1-slice-demo-seed-design.md) (slice overview, part 3). Story: `docs/03` L-1. Reqs: LRN-01 (lock order), LRN-03 (read side), LRN-07 (continue card, course-map version only). Screen: `docs/04` S-14.
Tier **L** (`docs/15` §2): the story is M, but it computes access (lock state) server-side, so it gets this spec, pgTAP and `/security-review`.
Design source: `docs/design/claude-design-export/Learning Path.dc.html` (course map, topic rows, lock message, continue card).

## Goal
A signed-in, enrolled student opens the Courses tab on staging and sees the demo course: a "Continue" card pointing at their next open topic, then the unit with its topics, each shown as **completed**, **open** or **locked**. Tapping an open or completed topic goes to a topic stub page. Locked topics cannot be opened and say why. Lock state is computed only by the server. This unblocks practice (part 4), which replaces the topic stub.

## Scope (decided 2026-10-17)
- **In:** a new read-only RPC `get_course_map`, the `course_map` client feature (data/domain/presentation), the course-map screen on the Courses tab, a topic stub screen, the carry-over auth items from part 2 (§5).
- **Out:** per-topic step progress rings (video and notes aren't in the slice; added when those steps land), My courses list (S-13; one enrolment is assumed, see §1), the Home continue card (S-12), the full topic page / 5-step stepper (S-15), `compute_unlocks` / `teacher_unlock` (part 5 and later), expiry/renewal banners from the design.
- **Anti-goals:** the client never decides lock state; no answer keys, scores beyond what `topic_progress` already exposes to the owner, or other students' data in the response.

## 1. Backend — `public.get_course_map(p_slug text default null) → jsonb`
New migration from `supabase/templates/`, passes `docs/16` §2. `security definer`, `set search_path = ''`, `stable`. `revoke ... from public`; `grant execute ... to authenticated` only (rule 9). Not callable by `anon`.

**Which course:** `p_slug` given → that published course. `p_slug` null → the caller's enrolment (any status) with the latest `starts_at`, then classified as below (slice assumption: one enrolment; My courses picks the slug later). *Claude's call:* any status, so an ended enrolment reports `access_expired`, not `not_enrolled`.

**Errors (`docs/07` §9):** no session → `not_authenticated`; unknown/unpublished slug → `invalid_input`; no enrolment for that course (or none at all when slug is null) → `not_enrolled`; enrolment status not `active` (expired, refunded, suspended) or `expires_at <= now()` → `access_expired`.

**No map without active access (decided by the user 2026-10-17):** a student without an active enrolment gets the error only — no map, not even free-preview topics. This is a course-map rule only; `docs/07` §2's "free-preview topics need no enrolment" still applies to the public course page (S-02) and is part 4's call for practice access.

**Staff (Claude's call):** teachers/admins are not auto-enrolled, so they get `not_enrolled` on the Courses tab in this slice. Expected on staging, not a bug; a staff preview belongs to the teacher area.

**Units:** units with no published topics are hidden (as `get_course_page` does); `sort_label` positions count shown units and published topics only.

**Status per published topic for the caller** — `docs/07` §2, in course order (`units.sort`, `topics.sort`, then title; topics with no unit come after all units):
| Status | Rule |
|---|---|
| `completed` | `topic_progress.quiz_passed_at` is not null |
| `open` | not completed, and any of: first published topic of the course · `is_free_preview` · previous published topic (course order) is completed · `topic_progress.unlocked_at` is not null |
| `locked` | otherwise |

"Previous topic" walks the whole course order, across units. Unpublished topics are skipped entirely (not shown, not counted as previous).

**Response shape:**
```json
{
  "course":   { "id", "slug", "title" },
  "continue": { "topic_id", "slug", "title", "unit_title" } | null,
  "units": [
    { "title": "Algebra (Demo)",
      "topics": [
        { "id", "slug", "title", "sort_label": "1.1", "is_free_preview": true,
          "status": "open", "locked_reason": null } ] } ]
}
```
- `continue` = first `open` topic in course order; null when none is open (all completed or all locked).
- `locked_reason` is a stable code, not copy: `previous_quiz` (with `"after_title"` of the previous topic) for locked topics; null otherwise. The client maps it to "Pass the <title> quiz to unlock".
- `sort_label` = `<unit position>.<topic position>` (1-based, published only), matching the design's "1.1"; topics with no unit get `<topic position>` only.
- Topics without a unit go in a final unit entry with `"title": null`.

**Tests (`supabase/tests/`, pgTAP):** not callable by `anon`; each error code; first topic open; free-preview topic open even when previous isn't passed; topic after a passed quiz is open, previous shows completed; teacher-unlocked topic open; ordering across units and unpublished-topic skipping; `continue` null when all completed; another student's progress has no effect (two users).

**Docs:** add the row to `docs/07` §1 RPC table; note in `docs/07` §2 that `get_course_map` is the read side of the state machine.

## 2. Client — `lib/features/course_map/` (ADR-007 §4)
```
data/
  datasources/course_map_remote_data_source.dart   rpc('get_course_map'), maps PostgrestException → AppError
  models/course_map_model.dart                     hand-written fromJson (B.2)
  repositories/course_map_repository_impl.dart     → Result<CourseMap>
domain/
  entities/course_map.dart       CourseMap, MapUnit, MapTopic, TopicStatus (enum: completed/open/locked),
                                 LockReason (sealed: PreviousQuiz(afterTitle))
  repositories/course_map_repository.dart
presentation/
  cubit/course_map_cubit.dart + course_map_state.dart   sealed: Loading | Loaded(map) | Failed(code)
  screens/course_map_screen.dart, topic_stub_screen.dart
  widgets/continue_card.dart, topic_row.dart
  course_map_copy.dart          error code → English copy
```
- Cubit depends on the repository interface (no pass-through use case, ADR-007 §5). Public methods: `load()` and `retry()`. `isClosed` check after await.
- DI in `lib/core/di/injection.dart`: data source + repo lazy singletons, cubit factory.
- **States on screen:** loading (skeleton or spinner), loaded, `not_enrolled` → "You're not enrolled in a course yet.", `access_expired` → "Your access has ended. Contact your teacher.", other errors → generic copy + Retry. No purchase CTA (ADR-006; purchase is web-only and not in this slice).
- **Topic row:** status icon + `sort_label` + title; free-preview badge; locked rows are not tappable and show the lock message; open row highlighted; completed row shows a check. Semantics label includes the status ("Linear Inequalities, locked").
- **Layout:** follows the Booklet theme tokens already in `lib/core/theme` and the Learning Path design; check at 360 px and 1280 px (B.9). Topic titles are plain English content; no special direction handling needed beyond what `MathText`/theme already do.

## 3. Routing
- The Courses shell branch (`AppRoutes.courses`, `/courses`) renders `CourseMapScreen` (null slug) instead of the placeholder.
- New child route `/courses/topics/:topicId` → `TopicStubScreen`: shows the topic title and "Practice is coming next." The title comes from `extra` when navigated from the map; on a cold deep link it shows a generic "Topic" title. The stub reads no data and grants no access — part 4's RPCs enforce `topic_locked` server-side.
- Locked rows never navigate. Auth guard unchanged (shell paths already require `AuthSignedIn`).

## 4. Done when
- pgTAP, `flutter analyze --fatal-infos`, `flutter test` green in CI; `/security-review` run on the migration.
- Cubit tests: `load` success, each error code, `retry`. Repository/model tests for parsing every status and a null `continue`. Widget tests for the three row states and the error/empty states.
- **Staging manual check:** an enrolled demo student opens Courses → sees "SAT Math (Demo)", Continue → "Linear Equations", 1.1 Linear Equations open (free), 1.2 Linear Inequalities and 1.3 Systems of Equations locked with "Pass the … quiz to unlock"; tapping 1.1 opens the stub; tapping a locked row does nothing. Checked at 360 px and 1280 px. (The completed state is covered by pgTAP; it can't be produced on staging until part 5.)
- `docs/STATUS.md` updated.

## 5. Carry-over from part 2 (STATUS Open → done here)
Small, separate commits on the same branch:
1. **Splash while `AuthBusy` on shell paths:** shell routes show a full-screen splash instead of the shell content while auth is `AuthUnknown`/`AuthBusy`, so the course map never fires its RPC without a session.
2. **AuthCubit hardening:** generation check in `_sessionLost` (ignore a stale loss from an older session); assert `refresh` is only passed together with `auth` in `createRouter`; test for a null `userChanges` event arriving during an in-flight `signIn`.

## Calls made by Claude (check these)
- Courses tab opens the latest enrolment's map directly (no My courses list yet); an ended enrolment → `access_expired`.
- Teachers/admins see `not_enrolled` on the Courses tab in this slice.
- Lock reasons are codes, copy lives in the client.
- `sort_label` is computed server-side to match the design's "1.1".
- Topic stub gets its title via route `extra`, generic on deep link.
- Carry-over auth items ship in this branch, not a separate PR.
