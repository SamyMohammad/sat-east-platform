# Lane 3c-2 — question bank browser + editor (C-5, QB-06) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## Context

3c-1 (import, #44/#45) lets the teacher load questions in bulk, but there is no way to see what is in the bank or fix one question without re-importing. 3c-2 adds:

- the **bank list** with filters (T-05);
- a **single-question editor** with a live student preview (T-06);
- creating a new question.

**Spec:** `docs/superpowers/specs/2026-10-21-p1-lane3c-question-bank-design.md` §Goals 5–7, D1, D6, D7.
**Worktree:** `C:/Users/Lenovo/sat-wt-lane3`, branch `feat/P1-lane3c2-question-editor` (from `main` at `b6981da`).
**Implementer:** Codex through `codex-delegate`, session `01a1557a-7e72-78d2-b2a5-621c59f92d2c`. Claude runs the Flutter gates; CI runs pgTAP on a **draft** PR. The PR stays draft until CI is green, and Claude tells the user "ready to merge" explicitly.

## Global constraints

- CLAUDE.md rules 1–10 (rule 1 already has the `teacher_*` exception), A, B; `docs/16` §2; SQL from `supabase/templates/`.
- Reserved:
  - Migration `20261024100000_lane3c2_question_editor.sql`.
  - pgTAP `35_question_editor.test.sql`.
  - Routes `/teacher/questions` (list), `/teacher/questions/new`, `/teacher/questions/:id`. `/teacher/questions/import` stays.
  - Folder: extend `lib/features/teacher/questions/`.
  - Setting `bank_page_size` = 25.
- **Reuse the validator:** `teacher_save_question` validates through the existing `private.validate_question_row` from 3c-1, so the rules live in one place. The editor sends the same row shape as an import row.
- **pgTAP role rule** (lesson from #45): after `tests.clear_authentication()`, run `reset role;` before any privileged step.
- No new package. `dart format` only touched files. Non-ASCII is written as `\u` escapes.

## RPCs (all `security definer`, `is_teacher()` else `forbidden`, granted to `authenticated` only)

- `teacher_list_questions(p_filter jsonb, p_page int)` → `{total, page, page_size, rows:[{id, external_ref, stem_preview, type, topic_title, subtopic_title, difficulty, pool, status, version, updated_at}]}`.
  - Filter keys (all optional): `course_code`, `topic_id`, `subtopic_id`, `status`, `pool`, `difficulty`, `type`, `q`. `q` is an ILIKE match on `external_ref` or `stem_md`, with `%`/`_` escaped.
  - Rows are ordered by `updated_at desc, id`. The page size comes from `settings.bank_page_size`.
  - **No keys** in the list.
- `teacher_get_question(p_id uuid)` → the full import-shaped row (`docs/09` §3 + `pool` + `status`), **including `key`, `explanation_md`, `misconceptions`, `solved_by`**, plus `id`, `version`, `updated_at`. An unknown id → `invalid_input`.
- `teacher_save_question(p_id uuid, p_row jsonb, p_expected_version int)` → `{id, version}`.
  - `p_id` null → create (`version` 1). An `external_ref` that is already taken → `invalid_input`.
  - Otherwise → update **only if** `version = p_expected_version`. A mismatch → raise `version_conflict` (new code in `docs/07` §9 and `ErrorCodes`). This prevents silent overwrites when the same question is open in two tabs.
  - Validation runs through `private.validate_question_row(p_row, 1)`. Any problem → returns `{ok:false, errors:[…]}` (same shape as import) and writes nothing.
  - **Status rule (D7):** any → `retired`; `retired` → `draft`; otherwise only forward in lifecycle order (skips allowed). A backward move other than → `draft`-from-`retired` → problem `bad_status_change`. Every move to `published` requires a valid key, which `validate_question_row` already guarantees.
  - The write replaces choices, courses and skills, upserts the key, bumps `version`, sets `updated_at`, and writes one `audit_log` row (`question.save`, `entity_id` = id, `diff` = `{from_version, to_version, status_from, status_to}`, **never the key**).
- `teacher_list_topics_tree()` → `[{course_code, topics:[{id, slug, title, subtopics:[{id, slug, title}]}]}]` for the filter and editor dropdowns. The subtopic slug is `private.slugify(title)`, matching the import resolution.

## Review focus

1. A student and anon get `forbidden` / no execute on all 4 RPCs. `teacher_list_questions` never returns key fields (pgTAP checks the keys of the row JSON).
2. Save with a stale `p_expected_version` → `version_conflict`, nothing changes.
3. Save with a bad row → `{ok:false, errors}`, nothing changes. A save that goes back to `draft` from `published` → `bad_status_change`.
4. The audit row has no key or explanation content.
5. The `q` search escapes `%` and `_`.
6. Client: the preview uses the **shared `QuestionView`** (rule 6) in `PracticeMode` with `Correct` feedback, so the key choice and explanation show as the student sees them after answering. There is no new QuestionView mode.
7. Client: the editor never validates rules itself beyond required-field UX. Server `problem` codes map to field errors through the 3c-1 problem copy.

---

### Task 0: Land the plan (Claude)
- [ ] Copy this plan to `docs/superpowers/plans/2026-10-24-p1-lane3c2-question-editor.md` and commit it.

### Task 1: Backend (Codex)
**Create:** the migration (the setting plus the 4 RPCs, with the status-change check added as a private helper), `supabase/tests/35_question_editor.test.sql`.
**Modify:** `docs/07` (RPC rows and §9 `version_conflict`), `apps/client/lib/core/errors/error_codes.dart` (`versionConflict`, also in `_serverCodes`).

- [ ] **Step 1: pgTAP first**:
  - Review focus 1–5.
  - Paging and every filter.
  - Create, then get round-trips the import shape.
  - An SPR save with tolerance.
  - The retire → draft allowed path.
- [ ] **Step 2: Implement.**
- [ ] **Step 3 (Claude):** push, open a draft PR, CI `db` green.

### Task 2: Bank list (Codex, after Task 1)
**Create** in `lib/features/teacher/questions/`:
- The entities `BankRow`, `BankPage`, `BankFilter`, `TopicOption`.
- `QuestionBankRepository` (`list`, `topics`).
- `QuestionBankCubit`: `load()`, `setFilter(BankFilter)`, `nextPage()`, `prevPage()`, `retry()`. The text search is debounced with an injected timer (no real timers in tests).
- `QuestionBankScreen`: the filter bar, then the table.
  - Columns: ref, stem preview (`MathText` single-line), type, topic, difficulty, pool, status chip.
  - Pager: "1–25 of N".
  - "New question" and "Import" buttons.
  - A row tap → the editor.
  - Empty, loading and error states.

**Modify:** `TeacherShell` "Questions" → `/teacher/questions`; the router routes; DI (append).

- [ ] **Step 1: Tests first**:
  - Models.
  - The repository error mapping.
  - Every cubit method on success and failure, including the debounce through a fake timer.
  - Widgets: the filters change the query, the pager, the row tap navigates, no overflow at 360/1280.
  - Router: a student going to `/teacher/questions` lands on `/`.
- [ ] **Step 2: Implement.**

### Task 3: Editor (Codex, after Task 2)
**Create:**
- `QuestionDraft` entity (the editable fields, including the MCQ/SPR key).
- `QuestionEditorRepository` (`get`, `save`).
- `QuestionEditorCubit`: `load(id?)`, `edit(...)` per field group, `save()`, `discard()`. States carry `draft`, `original`, `serverErrors`, `saving`, `conflict`.
- `QuestionEditorScreen`:
  - Form sections: Content (stem, hint, explanation), Answer (type switch; MCQ A–E with a key radio and a misconception per wrong choice; SPR accepted list + tolerance), Classification (course(s), topic, subtopic, skills, difficulty, pool, desmos_friendly), Source (ref, source, page), Status.
  - **Live preview** to the right at ≥ 1024 px and below the form under 1024: `QuestionView(mode: PracticeMode(feedback: Correct(explanationMd: …)), answer: key selected)`.
  - The Save bar (`LoadingButton`, dirty-only), Discard, and leave-with-unsaved-changes confirm.
  - On `version_conflict`: a banner "This question changed elsewhere. Reload to see the latest." with "Reload".
  - Text controllers are created in `initState` and disposed.

- [ ] **Step 1: Tests first**:
  - Draft ↔ JSON round trip.
  - Every cubit method on success and failure (server errors map to fields, conflict, discard).
  - Widgets: the MCQ ↔ SPR switch, the key radio drives the preview, the server error shows on the right field, the conflict banner, no overflow at 360/1280.
- [ ] **Step 2: Implement.**

### Task 4: Gates, review, PR (Claude)
- [ ] `dart format --set-exit-if-changed .`, `flutter analyze --fatal-infos`, `flutter test -j 2 --exclude-tags golden` + `--tags golden`.
- [ ] Diff against Review focus 1–7.
- [ ] STATUS: the 3c-2 row. Commit by path, push, **keep draft until CI is green**, then mark ready and tell the user "ready to merge".
- [ ] Staging check in Chrome (with the teacher role toggle):
  - Open the bank and filter on the demo topic.
  - Edit a demo question's hint, save, and see `version` + 1 in SQL.
  - Change it back.
  - Create a draft question, then retire it, then delete the test row in SQL.
  - Revert the role.

## Verification

- CI: `db` (pgTAP 35) + `client` green; local gates green.
- The staging steps above, plus SQL checks on `version`, `status` and `audit_log` (no key text in `diff`).
