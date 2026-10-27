# Lane 3a — teacher shell + course builder (C-1) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## Context

The teacher has no UI; content changes only through SQL. 3a gives the teacher a "Teacher area" in the same app with a course builder: build the units → topics → subtopics tree, order it, publish topics and flag free previews. 3b (settings, C-7) comes after it in its own plan.

**Spec:** `docs/superpowers/specs/2026-10-19-p1-lane3-teacher-builder-design.md` (user: "ok"). Decisions D1–D8 live there.
**Worktree:** `C:/Users/Lenovo/sat-wt-lane3`, branch `feat/P1-lane3-teacher-builder` (spec commit `6384d36`).
**Implementer:** Codex through `codex-delegate`, in a new session with `--cd C:/Users/Lenovo/sat-wt-lane3`. Codex writes the tests and doesn't commit. Codex can't run Docker or Flutter, so Claude runs the Flutter gates and CI runs pgTAP on a draft PR.

## Global constraints

- CLAUDE.md rules 1–10, A, B; `docs/16` §2. SQL starts from `supabase/templates/rpc.sql` and `test.sql`.
- Reserved:
  - Migration `20261019100000_lane3a_course_builder.sql`.
  - pgTAP `32_course_builder.test.sql`.
  - Error code `in_use`.
  - Routes `/teacher` and `/teacher/courses/:courseId`.
  - Folders `lib/features/teacher/{shell,course_builder}`.
- Append-only edits to `lib/core/di/injection.dart` and `lib/core/router/app_router.dart`.
- Codex: any non-ASCII literal (Arabic test strings) must be written as `\u` escapes; its sandbox mangles UTF-8 to `?`.
- Lint: `package:` imports, sorted directives, lines of 80 chars or fewer, inferred locals, `--fatal-infos`.

## Review focus

1. A student and anon get `forbidden` / no execute on **every** `teacher_*` RPC (pgTAP loops over all of them).
2. `teacher_reorder`: `p_ids` must equal the parent's current children exactly. A missing id, an extra id, a duplicate, or a child of another parent → `invalid_input`, with nothing changed. On success `sort` = 1..n.
3. `teacher_delete_node` → `in_use` when the row has children or any FK reference. FK references are checked for:
   - units: topics;
   - topics: subtopics, `topic_assets`, `questions`/`question_courses` via `topic_id`, `attempts`, `topic_progress`, `question_exposure`, and any other FK to `topics` (grep the schema);
   - subtopics: every FK to `subtopics`.
4. Slug: generated from the title, made unique per course with `-2`, `-3`, and unchanged on rename.
5. Every write inserts an `audit_log` row (`actor`, `action`, `entity`, `entity_id`, `diff`).
6. Client: the role gate redirects a non-teacher off `/teacher/**`, and the Teacher area entry only shows for a teacher.

---

### Task 0: Land the plan (Claude)
- [ ] Copy this plan to `docs/superpowers/plans/2026-10-19-p1-lane3a-course-builder.md` and commit it.

### Task 1: Backend (Codex), C-1 / ADM-01

**Create:** the migration, `supabase/tests/32_course_builder.test.sql`.
**Modify:**
- `docs/07` (RPC table rows + §9 `in_use`).
- `apps/client/lib/core/errors/error_codes.dart` (+`inUse`).

**Interfaces (all `security definer`, `set search_path = ''`, `is_teacher()` else `forbidden`, `grant execute … to authenticated`, revoked from `public, anon`):**
- `teacher_list_courses()` → `[{id, code, title, slug, is_published}]` ordered by `sort`.
- `teacher_get_course_tree(p_course_id)` → `{course:{id,title,code}, units:[{id,title,sort,in_use, topics:[{id,title,slug,sort,is_published,is_free_preview,subtopic_count,in_use, subtopics:[{id,title,sort,in_use}]}]}]}`, all rows, published or not. An unknown course → `invalid_input`.
- `teacher_upsert_unit(p_id uuid, p_course_id uuid, p_title text)`, `teacher_upsert_topic(p_id uuid, p_unit_id uuid, p_title text)` (the topic's `course_id` comes from its unit), `teacher_upsert_subtopic(p_id uuid, p_topic_id uuid, p_title text)`. `p_id` null → insert last (`max(sort)+1`), else rename. Each returns `{id}`. The title is trimmed to 1–120 chars, else `invalid_input`.
- `teacher_reorder(p_kind text /* unit|topic|subtopic */, p_parent_id uuid, p_ids uuid[])` → `{ok:true}`. It locks the parent row `for update`.
- `teacher_delete_node(p_kind text, p_id uuid)` → `{ok:true}`, or raises `in_use`.
- `teacher_set_topic_flags(p_id uuid, p_is_published boolean, p_is_free_preview boolean)`: a null leaves that flag unchanged. Returns the topic flags.
- A private helper `private.slugify(text)` (unaccented lower-case ASCII, non-alnum → `-`, trimmed; empty → `topic`). Revoked from everyone.

- [ ] **Step 1: pgTAP first**: Review focus 1–5. Also: the happy path of each RPC; the tree includes unpublished rows; the topic upsert under a unit of another course is impossible (course from unit); renaming keeps the slug; the flags partial update.
- [ ] **Step 2: Implement.**
- [ ] **Step 3 (Claude):** push, open a draft PR, CI `db` green.

### Task 2: Client role + teacher shell (Codex)

**Modify:**
- `AppUser` gains `isTeacher` (default false; in props).
- The auth data source reads the caller's own `profiles.role` when it builds the signed-in user. If the `role` column isn't selectable for `authenticated`, add a tiny `get_my_role()` RPC to the Task 1 migration instead, and say which in the report.
- `AuthCubit` keeps `isTeacher` on `AuthSignedIn`.
- The router:
  - `/teacher` redirects to the first course from `teacher_list_courses` (resolved in the screen, not the router).
  - `/teacher/**` for a non-teacher → `/`.
  - The routes sit top-level, outside the student shell.
- The Profile tab / My account: show a "Teacher area" link only when `isTeacher`.

**Create:** `lib/features/teacher/shell/teacher_shell.dart`. It shows a side nav at ≥ 1024 px and a drawer below that. The items are "Course builder", "Settings" (disabled placeholder until 3b) and "Back to app".

- [ ] **Step 1: Tests first**: role parsing (teacher/student/missing), the cubit carries `isTeacher`, the router gate (teacher allowed, student → `/`, signed-out → sign-in), the shell at 360 and 1280, the link visibility.
- [ ] **Step 2: Implement.**

### Task 3: Course builder UI (Codex, after Tasks 1–2)

**Create** `lib/features/teacher/course_builder/{data,domain,presentation}` (mirror `lib/features/activation/**`):
- Entities `CourseTree`, `BuilderUnit`, `BuilderTopic`, `BuilderSubtopic`, `TeacherCourse`, and a `NodeKind` enum.
- `CourseBuilderRepository` covers every Task 1 RPC (`Result<T>`).
- `CourseBuilderCubit`: `load(courseId)`, `addUnit`, `addTopic(unitId)`, `addSubtopic(topicId)`, `rename(kind, id, title)`, `reorder(kind, parentId, ids)` (optimistic, rolls back on failure), `delete(kind, id)`, `setFlags(topicId, …)`. Each mutation reloads the tree on success. The sealed states are `Loading`, `Loaded(tree, busyId?, lastError?)` and `Failed`.
- `CourseBuilderScreen`:
  - A course dropdown, then the tree with `u.t.s` numbers and the Free preview + Draft/Published columns, per `docs/design/claude-design-export/Teacher Area B.dc.html`.
  - Inline rename.
  - "Add unit / topic / subtopic".
  - Reorder: `ReorderableListView` per level with a drag handle, plus up/down `IconButton`s.
  - The row menu: Delete, disabled with a tooltip "In use" when `in_use`.
  - The publish confirm dialog: "Publish {n.t} {title}? Students on the path will see it."
  - `in_use` / `forbidden` / network → a SnackBar with mapped copy, never raw text.
  - Content titles use the direction helper `lib/core/text/text_direction.dart`.

- [ ] **Step 1: Tests first**:
  - The models parse the tree JSON.
  - The repository maps every error.
  - Every cubit method on success and failure, including the reorder rollback.
  - Widget tests: tree render + numbering, add, rename, reorder by buttons, delete disabled when `in_use`, the publish confirm, error SnackBar copy, 360 px with no overflow.
- [ ] **Step 2: Implement.**

### Task 4: Gates, review, PR (Claude)
- [ ] Run `dart format .`, `flutter analyze --fatal-infos`, `flutter test -j 2 --exclude-tags golden` and `--tags golden` (from `apps/client`).
- [ ] Read `git diff --stat`, then the hunks against Review focus 1–6. Grep the new files for `?????`.
- [ ] `/flutter-code-review`, then offer `code-reviewer`.
- [ ] STATUS: the 3a row → PR, the 3b row next. Commit by path, push, mark the PR ready: "feat(P1): teacher area + course builder (C-1, ADM-01)".

## Verification

- CI: `db` (pgTAP 32) + `client` green.
- Local gates green.
- Staging, after merge (user): set your account to `role='teacher'` in the staging dashboard (`docs/setup/` note to add in Task 1), open `#/teacher`, add a unit, a topic and a subtopic, reorder them, publish → the student course map reflects the order. A student account opening `#/teacher` → bounced to `/`.
