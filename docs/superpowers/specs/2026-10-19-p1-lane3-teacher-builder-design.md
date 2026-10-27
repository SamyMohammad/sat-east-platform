# Lane 3a/3b — teacher area: course builder (C-1) + settings (C-7) — design

> Status: draft · 2026-10-19 · Branch `feat/P1-lane3-teacher-builder`
> The user skipped the question round ("ابدأ"). Every decision below is the router's call unless marked **user**.

## Intent

The teacher has no UI today. Content and settings only change through SQL. Lane 3 gives the teacher a laptop-first area in the same app, starting with the two smallest pieces that unblock real content:

- **3a — C-1 course builder (T-02):** build the syllabus tree (units → topics → subtopics) and set the order students follow.
- **3b — C-7 settings (T-17):** change pass mark, cooldown, device limit, quiz size/timing and the access window without SQL.

They ship as two PRs from one spec: 3a first, then 3b, because 3b reuses 3a's teacher shell. C-4/C-5 (question import + editor) is lane 3c and gets its own spec later.

## Current state

- **Roles.** `profiles.role` holds the role, and `public.is_teacher()` checks it. Every public table has a permissive policy, "teacher manages all" (`20261007003820_f2_rls_policies.sql`), so the teacher can already write `courses`, `units`, `topics`, `subtopics` and `settings` through RLS.
- **Client.** The client does not read the role and has no teacher routes.
- **Content tables.** `units(course_id, title, sort)`, `topics(course_id, unit_id, title, slug, sort, is_free_preview, is_published)` with `unique(course_id, slug)`, and `subtopics(topic_id, title, sort)`. Every FK is `on delete restrict`.
- **Student path.** The path order is `units.sort`, then `topics.sort` (`private.topic_states`); position 1 is always open. Reordering therefore changes students' lock path.
- **Settings.** The settings keys are `pass_mark`, `cooldown_h`, `device_limit`, `homework_size`, `practice_min`, `access_grace_days`, `access_min_days`, `test_date_max_days`, `ai_daily_cap`, `quiz_size`, `quiz_time_per_q_s`, `quiz_warn_s`, `review_max`, `review_per_skill`, `currency_by_country`, `device_header_required`, the `rate_*` keys and a few internal timers. **There is no pool-split key yet.** `audit_log` is insert-only from `security definer` functions.
- **Design.** `docs/design/claude-design-export/Teacher Area B.dc.html` holds the course builder (tree, drag handle, Free preview column, status, side panel, publish checklist). `Teacher Area C.dc.html` / T-17 holds settings.

## Goals

### 3a — teacher shell + course builder
1. **Role on the client.** After sign-in the app reads the caller's own `profiles.role`. A teacher sees a "Teacher area" entry (`/teacher`); a student never sees it. The gate is UX only, because RLS and the RPCs enforce the role (rule 2).
2. **Teacher shell.** A side-nav layout for laptops (≥ 1024 px), which collapses to a drawer on narrower screens. For now the nav has "Course builder" and "Settings" (3b), plus "Back to app".
3. **Course builder** (`/teacher/courses/:courseId`; `/teacher` opens the first course). It works on both courses: the course is picked from a dropdown that lists all courses, published or not.
   - Tree rows are units → topics → subtopics, numbered `u.t.s`. Each row shows the title, the counts, a Free-preview toggle (topics only) and a Draft/Published status (topics only).
   - Add a unit, a topic in a unit, or a subtopic in a topic. A new topic is a **draft**.
   - Rename any row inline.
   - Reorder within the same parent: drag handle plus keyboard (Space picks up, arrows move, Space drops, Esc cancels, as in the design), with **up/down buttons as the accessible fallback**. Moving a topic to another unit is **out** for 3a.
   - Delete a row only when it has no children and nothing references it (questions, assets, attempts). Otherwise the server answers `in_use` and the UI says why.
   - Publish or unpublish a topic, and toggle Free preview. Publishing asks to confirm with copy that says students on the path will see the topic.

### 3b — settings
4. **Settings screen** (`/teacher/settings`). Grouped fields:
   - Quiz: `pass_mark` %, `cooldown_h`, `quiz_size`, `quiz_time_per_q_s`, `quiz_warn_s`.
   - Practice: `practice_min`, `homework_size`, `review_max`, `review_per_skill`.
   - Access: `access_grace_days`, `access_min_days`, `test_date_max_days`.
   - Devices: `device_limit`.
   - AI: `ai_daily_cap`.

   Every field shows its current value and allowed range. "Save" writes only the changed keys. `currency_by_country`, `device_header_required`, the `rate_*` keys, `practice_stale_h`, `save_grace_s` and `video_done_pct` are **not editable** in 3b.

## Non-goals

- The topic editor (T-03: videos, notes, pools, the publish checklist), video upload (C-2), notes and book (C-3), and the question bank (C-4/C-5, lane 3c).
- Pool split (C-7 lists it, but no setting exists; it comes with the quiz blueprint / spiral work).
- The teacher dashboard (T-01), students (T-09/T-10) and course create/delete. The two courses come from seed data; course **title/description edit** is also out.
- Moving topics across units, and moving subtopics across topics.
- An admin role distinct from the teacher.

## Anti-goals

- A student reaching any teacher write, even by URL or a crafted request. The server must reject it (`forbidden`), and pgTAP must prove it.
- A reorder that leaves duplicate or gapped `sort` values, or that half-applies. Each reorder is one transaction.
- A settings save that stores an out-of-range value, for example `pass_mark` 0 or 150. Validation is server-side; the client checks are UX only.
- Silent changes. Every teacher write lands in `audit_log`.

## Decisions

| # | Decision |
|---|----------|
| D1 | **All writes go through `security definer` RPCs**, not direct table writes. Each RPC checks `is_teacher()` (else `forbidden`), validates its input, writes `audit_log`, and is granted to `authenticated` (rule 9). The RLS policy "teacher manages all" stays as it is. **Reads** for the builder go through one RPC, `teacher_get_course_tree(p_course_id)`, which returns all units, topics (published or not) and subtopics with their counts and an `in_use` flag per row. |
| D2 | RPCs (3a): `teacher_list_courses()`, `teacher_get_course_tree(p_course_id)`, `teacher_upsert_unit(p_id?, p_course_id, p_title)`, `teacher_upsert_topic(p_id?, p_unit_id, p_title)`, `teacher_upsert_subtopic(p_id?, p_topic_id, p_title)`, `teacher_reorder(p_kind, p_parent_id, p_ids uuid[])`, `teacher_delete_node(p_kind, p_id)`, `teacher_set_topic_flags(p_id, p_is_published?, p_is_free_preview?)`. A new row goes last (`max(sort)+1`). `teacher_reorder` requires `p_ids` to be exactly the parent's current children, in any order. It locks the parent and rewrites `sort` as 1..n; a mismatch → `invalid_input`. |
| D3 | **The topic slug** is generated on the server at create time from the title (lower-case ASCII, `-` separated; when nothing is left, `topic`), with a `-2`, `-3` suffix on clash. It never changes on rename, so links stay stable. |
| D4 | **New error code `in_use`** (docs/07 §9): a delete is blocked because the row has children or references. Titles are trimmed, 1–120 chars, else `invalid_input`. |
| D5 | Settings (3b): `teacher_update_settings(p_values jsonb)`. Each key is checked against a server-side allow-list with type and range: `pass_mark` 1–100, `cooldown_h` 0–168, `device_limit` 1–5, `practice_min` 0–50, `homework_size` 1–60, `access_grace_days` 0–60, `access_min_days` 1–365, `test_date_max_days` 30–730, `ai_daily_cap` 0–200, `quiz_size` 1–60, `quiz_time_per_q_s` 15–600, `quiz_warn_s` 0–1800, `review_max` 1–30, `review_per_skill` 1–10. An unknown key or a bad value → `invalid_input` with nothing written (all or nothing). Reads go through the existing `settings` select. |
| D6 | **Client role:** `AuthRepository` (or a small `ProfileRepository` already used by My account) exposes the role from the caller's own profile row. `AuthSignedIn` gains `isTeacher`. The router allows `/teacher/**` only when `isTeacher`; otherwise it redirects to `/`. |
| D7 | Feature folders: `lib/features/teacher/course_builder/{data,domain,presentation}` and `lib/features/teacher/settings/…`. The teacher shell widget lives in `lib/features/teacher/shell/`; it is not a shared widget, since only teacher screens use it. |
| D8 | The UI follows `Teacher Area B` (builder) and T-17 (settings) at 1280 px. At 360 px it must stay usable (single column, a drawer nav); pixel fidelity is not required. |

## Constraints

- CLAUDE.md rules 1–10, A, B; `docs/16` §2. SQL starts from `supabase/templates/`.
- pgTAP: every RPC has a happy path, a student gets `forbidden`, an anon gets no execute, invalid input is rejected, a delete in use gets `in_use`, the reorder is atomic with a mismatch rejected, an `audit_log` row is written, and the settings range is enforced (all or nothing).
- Shared hotspots (STATUS): append-only edits to DI and the router. Migration names and the `in_use` code are reserved in the plan.
- Codex can't run Docker or Flutter: Claude runs the Flutter gates, and CI runs pgTAP on a draft PR.

## Left to the builder

- Exact widget composition, the drag implementation (`ReorderableListView` per level or similar) and the row menu contents.
- How `in_use` is computed (an `exists` check per FK table).
- The copy for confirmations and errors, in the design's voice (English).
