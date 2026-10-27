# Lane 3c-1 — question import (C-4, QB-05) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## Context

Questions reach the bank only through SQL seeds today, but about 16,000 questions will come out of the content pipeline as JSON (`docs/09`). 3c-1 lets the teacher upload a pipeline JSON file, see a full validation report, and commit the whole file in one transaction only when it has 0 errors (**user**: all-or-nothing). The teacher can read keys only through teacher RPCs (**user**: an extension of rule 1). 3c-2 (the browser and the editor) gets its own plan.

**Spec:** `docs/superpowers/specs/2026-10-21-p1-lane3c-question-bank-design.md` (user: "go"). Decisions D1–D8 live there.
**Worktree:** `C:/Users/Lenovo/sat-wt-lane3`, branch `feat/P1-lane3c-question-bank` (spec commit `cc1e143`, from `main` at `2ae0b58`; #43 is still open and doesn't touch these files).
**Implementer:** Codex through `codex-delegate`, session `01a1557a-7e72-78d2-b2a5-621c59f92d2c`. Claude runs the Flutter gates; CI runs pgTAP on a draft PR.

## Global constraints

- CLAUDE.md rules 1–10, A, B; `docs/16` §2; SQL from `supabase/templates/` (`rpc.sql`, `setting.sql`, `test.sql`).
- Reserved:
  - Migration `20261022100000_lane3c_question_import.sql`.
  - pgTAP `34_question_import.test.sql`.
  - Route `/teacher/questions/import`.
  - Folder `lib/features/teacher/questions`.
  - Setting `import_max_rows` = 500.
- No new error codes: `invalid_input`, `forbidden`, `not_authenticated` are reused. Row problems are **returned** in the report, not raised. A raise only happens on a commit with errors (nothing is written).
- No new package. Web file read uses the existing `web: ^1.1.1` (`HTMLInputElement` type=file + `FileReader`) behind a small data-layer `FilePickerService` interface. On non-web it returns `unsupported`, and the screen shows "Import works in the web app."
- `dart format` touches only edited files. Non-ASCII is written as `\u` escapes.

## Import format (row)

This is `docs/09` §3 plus the required `pool` (`practice`|`quiz`|`mock_reserve`) and `status` (`draft`|`solved`|`needs_review`|`approved`|`published`).

- **Required:** `external_ref`, `course_codes`, `topic_slug`, `subtopic_slug`, `type`, `difficulty`, `stem_md`, `key`, `pool`, `status`.
- **Optional:** `skill_codes`, `images`, `choices` (MCQ), `explanation_md`, `misconceptions`, `hint_md`, `desmos_friendly`, `source`, `source_page`, `solved_by`.

**Resolution rules:**
- The topic resolves by `topics.slug` within the course of `course_codes[0]`.
- The subtopic resolves by `private.slugify(subtopics.title)` within that topic. `private.slugify` already exists from 3a.
- Every code in `course_codes` must exist. One `question_courses` row is written per code.

## Problem codes (report `problem` values)

| Code | When |
|------|------|
| `missing:<field>` | A required field is absent or empty |
| `bad_enum:<field>` | `type`, `difficulty`, `pool`, `status` or `solved_by` holds an unknown value |
| `unknown_course:<code>` | A code in `course_codes` doesn't exist |
| `unknown_topic` | `topic_slug` doesn't resolve |
| `unknown_subtopic` | `subtopic_slug` doesn't resolve |
| `unknown_skill:<code>` | A skill code doesn't exist |
| `mcq_choices` | MCQ without 2–5 choices, or labels that aren't unique A–E |
| `key_not_in_choices` | The MCQ `key.choice` isn't one of the choice labels |
| `spr_has_choices` | An SPR row has choices |
| `spr_key` | `accepted` is empty, an entry doesn't parse with `private.spr_parse`, or `tolerance` < 0 / not a number |
| `duplicate_ref` | An `external_ref` repeats within the file |
| `too_long:<field>` | The stem is over 5000 chars, or a choice or explanation is over 1000 / 5000 chars |
| `too_many_rows` | The file has more rows than `import_max_rows` (reported as row 0) |

## Review focus

1. A student and anon get `forbidden` / no execute. `private.question_keys` stays unreachable over REST (`scripts/api-private-check.ps1` is unchanged).
2. Dry run (`p_commit=false`) writes **nothing** (pgTAP compares row counts before and after).
3. A commit with ≥ 1 bad row raises `invalid_input`, and the counts are unchanged.
4. Re-importing a ref updates in place: `version` + 1, choices/courses/skills replaced, key upserted, `updated_at` bumped.
5. Each problem code has one failing pgTAP case. A valid MCQ row and a valid SPR row both commit.
6. One `audit_log` row per committed batch (`questions.import`, `diff` = `{created, updated, refs}`).
7. The client sends the parsed array **unchanged**, so no validation logic is duplicated in Dart. Problem codes map to copy in presentation.

---

### Task 0: Land the plan (Claude)
- [ ] Copy this plan to `docs/superpowers/plans/2026-10-22-p1-lane3c1-question-import.md` and commit it.

### Task 1: Backend (Codex)

**Create:**
- The migration, which adds the setting, `private.validate_question_row(p_row jsonb, p_index int)`, which returns `setof jsonb` problems, and `public.teacher_import_questions(p_items jsonb, p_commit boolean)`.
- `supabase/tests/34_question_import.test.sql`.

**Modify:**
- `docs/07` (the RPC row, plus the note "teacher_* RPCs may read/write keys for the teacher only").
- `docs/09` §1–3: import is an RPC rather than an EF; add the `pool`/`status` fields.
- `CLAUDE.md` rule 1: one clause noting the teacher-only exception (D1).

**Return value:** `{ok, rows, new, updated, errors:[{row, external_ref, field, problem}], truncated}`. Errors are capped at 200.
- `new` / `updated` are computed by `external_ref` existence.
- On commit, the write is set-based where practical: questions are upserted on `external_ref`; choices, courses and skills are deleted and re-inserted for the affected ids; `question_keys` is upserted.

- [ ] **Step 1: pgTAP first**: Review focus 1–6.
- [ ] **Step 2: Implement.**
- [ ] **Step 3 (Claude):** push, open a draft PR, CI `db` green.

### Task 2: Import screen (Codex, after Task 1)

**Create** `lib/features/teacher/questions/{data,domain,presentation}`:
- `ImportReport` entity (`rows`, `newCount`, `updatedCount`, `errors: List<ImportProblem>`, `truncated`, `ok`).
- `QuestionImportRepository`: `dryRun(List<Object?> items)`, `commit(List<Object?> items)`.
- `FilePickerService`: `pickJson()` → `Result<PickedFile(name, text)>`. It has a web implementation and a stub implementation.
- `QuestionImportCubit`: `pick()`, `validate()`, `commit()`, `reset()`. States: `Idle`, `Reading`, `Validating`, `Reported(file, report)`, `Committing`, `Committed(report)`, `Failed(error)`.
  - The JSON is parsed in the cubit's domain helper. Bad JSON, or JSON that isn't an array → `Failed(invalid_input)` with the copy "This file isn't a JSON array of questions."
- `QuestionImportScreen` in `TeacherShell`:
  - A file card ("Choose file", the file name and the row count).
  - The report: totals, then an errors table (row, ref, field, problem copy), with "Showing first 200" when truncated.
  - "Import {n} questions", enabled only when `errors.isEmpty`.
  - The success summary, plus "Import another".

**Modify:**
- `TeacherShell`: a "Questions" nav item → `/teacher/questions/import` for now (3c-2 repoints it to the list).
- The router: the route under the teacher gate.
- DI: append.

- [ ] **Step 1: Tests first**:
  - The report model parsing.
  - The repository error mapping.
  - Every cubit method on success and failure (bad JSON, non-array, server error, a report with errors where commit is blocked, a clean report then commit).
  - Widgets: the errors table, the Import button disabled when there are errors, the success state, no overflow at 360 / 1280.
  - The stub picker → the "web app" copy.
  - Router: a student going to `/teacher/questions/import` lands on `/`.
- [ ] **Step 2: Implement.**

### Task 3: Gates, review, PR (Claude)
- [ ] `dart format --set-exit-if-changed .`, `flutter analyze --fatal-infos`, `flutter test -j 2 --exclude-tags golden` + `--tags golden`.
- [ ] Diff against Review focus 1–7; grep new Dart for hardcoded problem logic.
- [ ] STATUS: a 3c-1 row. Commit by path, push, mark ready: "feat(P1): question import (C-4, QB-05)".
- [ ] Staging check in Chrome (after merge, with the teacher role toggle):
  - Import a 3-row sample file (one MCQ, one SPR, one with a bad skill) → see the report.
  - Fix the file → commit → check the rows in SQL.
  - Re-import → `version` 2.
  - Clean up the sample rows (refs `QA-IMP-*`).

## Verification

- CI: `db` (pgTAP 34) + `client` green. Local gates green.
- Staging steps above, plus `select external_ref, version, status from questions where external_ref like 'QA-IMP-%'`.
