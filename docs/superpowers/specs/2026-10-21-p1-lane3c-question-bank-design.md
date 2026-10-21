# Lane 3c — teacher question bank: import (C-4) + editor (C-5) — design

> Status: draft · 2026-10-21 · Branch `feat/P1-lane3c-question-bank`
> The user skipped the open questions ("ok"). Decisions marked **user** come from the two questions the user answered; every other decision is the router's call.

## Intent

The question bank is on the critical path (`docs/09`): about 16,000 SAT questions plus EST arrive from the content pipeline as JSON. Today the only way in is SQL seeds. Lane 3c lets the teacher **import** pipeline output with a validation report (C-4, T-07) and **browse and edit** single questions with a live preview (C-5, T-05/T-06).

It ships as two PRs:

- **3c-1:** import.
- **3c-2:** the bank browser and the editor.

The review queue (C-6, T-08) is a later story.

## Current state

- **Tables.** `questions`:
  - `external_ref` (unique), `topic_id`, `subtopic_id`, `type mcq|spr`, `difficulty E|M|H`, `stem_md`, `image_paths[]`, `hint_md`, `desmos_friendly`, `pool`, `status`, `source`, `source_page`, `version`.
  - `pool` values: `practice` / `quiz` / `mock_reserve`.
  - `status` values: `draft` → `solved` → `needs_review` → `approved` → `published` → `retired`.
- **Related tables.**
  - `question_choices(label, body_md)`, `question_courses`, `question_skills`.
  - `skills(code, …)`.
  - `private.question_keys(correct_answer jsonb, explanation_md, misconceptions jsonb, solved_by)`.
- **Import format.** `docs/09` §3 defines one JSON object per question. The format has no `pool` or `status`; pool assignment (§5) happens before import.
- **Existing helpers.**
  - The SPR grader helpers `private.spr_parse` and `private.grade_spr` (GRD-02) already exist.
  - The `invalid_key` error code exists.
  - `MathText` (`lib/shared/widgets/`) renders Markdown + LaTeX, and `QuestionView` renders a whole question.
- **Courses and skills.** The demo course has three topics. The `skills` table may be empty on staging; the skill taxonomy is a teacher deliverable (`docs/09` §4).

## Goals

### 3c-1 — Import (C-4, QB-05)
1. **Upload screen** (`/teacher/questions/import`): pick a `.json` file (an array of `docs/09` §3 objects, extended per D3). The client parses it and sends it to the server in one call. The cap is 500 questions per file (`settings.import_max_rows`).
2. **Dry run first.** The server validates every row and returns a report: totals (rows, new, updates), then a list of `{row, external_ref, field, problem}`. The screen shows that report.
3. **All or nothing (user).** "Import" is enabled only when the report shows 0 errors. Then every row is written in **one transaction**. Re-importing an `external_ref` that already exists updates that question in place (`version + 1`).
4. **Result.** A summary of how many questions were created and updated, with a link to the bank filtered by this batch.

### 3c-2 — Bank browser + editor (C-5, QB-06)
5. **Bank list** (`/teacher/questions`).
   - Filters: course, topic, subtopic, status, pool, difficulty, type, and text search (`external_ref` or stem).
   - Paged 25 at a time.
   - Columns: ref, the stem preview (first line), type, topic, difficulty, pool, status.
6. **Editor** (`/teacher/questions/:id`). It edits every QB-01 field: stem, choices (MCQ, A–D) with per-choice misconception, the key (MCQ choice / SPR accepted list + tolerance), explanation, hint, topic/subtopic, skills, difficulty, pool, `desmos_friendly`, source.
   - A **live preview** beside the form at ≥ 1024 px, or below it on narrower screens, uses the real `QuestionView` in review mode, so the teacher sees what students see.
   - Status changes follow the lifecycle (D7).
   - "Save" writes one transaction and bumps `version`.
7. **New question** from the list ("New question" opens an empty editor in `draft`).

## Non-goals

- The review queue and student reports (C-6), and the bulk actions in the design (bulk retire, bulk "add to pool").
- Image upload. `images` / `image_paths` are stored as given; uploading the files to Storage is a later story (with C-3).
- CSV import. JSON only, which is what the pipeline produces.
- Skill taxonomy management. Skills must already exist; an unknown skill code is an import error.
- Deleting questions. Retire is the only removal, since attempts reference questions.

## Anti-goals

- **A key reaching a student.** Teacher RPCs that return keys check `is_teacher()`. pgTAP proves a student and anon get `forbidden` / no execute. Student RPCs are unchanged.
- **A half-imported file.** It's all or nothing, inside one transaction.
- **A `published` question that students can't answer:** a missing key, MCQ without exactly one key choice among its labels, or an SPR key the grader can't parse. The server blocks publishing these, whether the question comes through import or the editor.
- **A silent overwrite.** Updates through import or the editor bump `version` and write `audit_log`.

## Decisions

| # | Decision |
|---|----------|
| D1 | **Rule 1 extension (user).** Teacher-only `security definer` RPCs may read and write `private.question_keys`: `teacher_import_questions` and `teacher_get_question` / `teacher_save_question` (3c-2). CLAUDE.md rule 1 and `docs/07` get one line saying so. No student path changes. |
| D2 | Import is an **RPC**, not the `import-questions` Edge Function in `docs/09` §2: `teacher_import_questions(p_items jsonb, p_commit boolean)`. No secret is needed, and an RPC keeps validation and writes in one transaction. `p_commit = false` → report only; `true` → validate again, then write all rows or raise `invalid_input` with nothing written. `docs/09` is updated to match. |
| D3 | **Import format** = `docs/09` §3 plus two required fields, `pool` (`practice`/`quiz`/`mock_reserve`) and `status` (`draft`…`published`; not `retired`). `topic_slug` / `subtopic_slug` resolve within the first course in `course_codes`; the subtopic is matched by title slug within its topic (the builder has no subtopic slugs yet). This is the builder's call if a cleaner match exists. |
| D4 | **Validation per row:** the required fields are present; the enums are valid; the course codes exist; topic and subtopic resolve; the skill codes exist; MCQ has 2–5 choices with unique labels A–E and `key.choice` among them; SPR has no choices and every `key.accepted` parses via `private.spr_parse`, with `tolerance` ≥ 0; `external_ref` is unique **within the file**; text lengths are capped (stem ≤ 5000, choice ≤ 1000). LaTeX compile checks stay in the pipeline's validator, not on the server. |
| D5 | **The report shape** is `{ok, rows, new, updated, errors:[{row, external_ref, field, problem}]}`. `problem` is an English code-like string such as `unknown_skill:ALG.X` or `key_not_in_choices`, and the client maps each code to copy. Errors are capped at 200 in the response, with a `truncated` flag. |
| D6 | **Writes:** questions are upserted on `external_ref`. Choices, courses and skills are replaced for that question, and `question_keys` is upserted. One `audit_log` row is written per batch (`questions.import`, with counts and refs), plus one per edited question in 3c-2. |
| D7 | **Status changes in the editor:** any status → `retired`, and `retired` → `draft`. Forward moves follow the lifecycle order, with skips allowed (for example `draft` → `published`) **only if** the key is valid (anti-goal 3). Students only ever see `published`; that is unchanged. |
| D8 | Client folders: `lib/features/teacher/questions/{data,domain,presentation}`. The teacher shell nav gains "Questions" (list) and "Import" (inside Questions). Reading the file uses `file_picker` **only if** it isn't already a dependency. Otherwise the web build uses `<input type=file>` via `package:web`, and the apps fall back to the same picker; this is the builder's call, with the reason stated. |

## Constraints

- CLAUDE.md rules 1–10, A, B; `docs/16` §2; SQL from `supabase/templates/`. A new setting (`import_max_rows` 500) goes through `supabase/templates/setting.sql`.
- pgTAP:
  - The forbidden/anon checks on every new RPC.
  - The dry run writes nothing.
  - A commit with any bad row writes nothing.
  - Upsert bumps `version`.
  - Each D4 rule has one failing case.
  - The publish guard.
  - An audit row is written.
- Performance: a commit of 500 rows must finish within the PostgREST timeout. Use set-based inserts, not a loop of single inserts, where practical.
- Codex can't run Docker or Flutter. Claude runs the gates, and CI runs pgTAP on a draft PR.

## Left to the builder

- The list widget, the filter layout and the editor layout, following `Teacher Area B.dc.html` (bank browser, editor).
- How the subtopic match works (D3), and the file-reading approach (D8).
- The exact copy for each problem code.
