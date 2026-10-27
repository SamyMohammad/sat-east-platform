# C-6 — question reports + teacher review queue (QB-04, QB-08, T-08) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## Context

Students have no way to flag a broken question, and the teacher has no queue of questions that need attention. `question_reports` exists, but nothing uses it. It also has a direct student `insert` policy with no rate limit, no duplicate check and no access check.

This story adds:
- a **"Report a problem"** action, in practice for now;
- a teacher **Review queue** that groups reports per question and lists `needs_review` questions, with resolve-all;
- a reports panel inside the question editor.

**Spec:** `docs/superpowers/specs/2026-10-24-p1-c6-review-queue-design.md` (user: "go"; D1–D5).
**Worktree:** `C:/Users/Lenovo/sat-wt-lane3`, branch `feat/P1-c6-review-queue` (spec commit `ca66671`, from `main` at `6516a74`).
**Implementer:** Codex through `codex-delegate`, session `01a1557a-7e72-78d2-b2a5-621c59f92d2c`. Claude runs the gates; CI runs pgTAP. The PR stays a **draft until CI is green**, then Claude tells the user "ready to merge".

## Global constraints

- CLAUDE.md rules 1–10, A, B; `docs/16` §2; SQL from `supabase/templates/`.
- pgTAP: run `reset role;` after `tests.clear_authentication()`. Never put `$$` inside a function body.
- Reserved:
  - Migration `20261029100000_c6_review_queue.sql`.
  - pgTAP `39_review_queue.test.sql`.
  - Setting `rate_report_per_min` = 5.
  - Route `/teacher/review`.
  - Folder `lib/features/teacher/review/`.
  - Shared widget `lib/shared/widgets/report_problem_sheet.dart`.
- No new error codes. The calls return `invalid_input`, `forbidden` or `not_authenticated`. A rate limit is **returned** as `{ok:false, error:'rate_limited'}` and never raised; follow how `redeem_activation_code` (`20261018400000_lane1b_activation.sql`) keeps the quota increment.
- Append-only edits to DI and the router. Run `dart format` only on touched files. Write non-ASCII as `\u` escapes.

## Review focus

1. **The student's write path.** The direct `insert` policy is dropped (pgTAP: a direct insert as a student fails). `report_question` checks all of the following, in this order:
   - auth;
   - the reason is in the allow-list;
   - the note is ≤ 500 characters;
   - the question is `published` and `has_access_topic` passes for its topic, otherwise `invalid_input`;
   - the rate limit.
2. **One open report per student and question.** A partial unique index enforces it. A duplicate returns `{ok:true, report_id, existing:true}` and inserts no row. After the report is resolved, the student can report again.
3. **Resolve.** `teacher_resolve_reports(q, 'fixed'|'dismissed', note)` closes **all and only** that question's open reports. It sets `status`, `resolved_at`, `resolved_by` and `teacher_note`, and writes one audit row.
4. **Teacher reads.**
   - `teacher_list_review_queue('reported'|'needs_review', page)` returns groups ordered by open count desc, then oldest report. It is paged by `bank_page_size`.
   - `teacher_list_question_reports(q)` lists the reports, and the student's name is shown only to the teacher.
   - `teacher_review_counts()` returns the counts for the badge.
   - All of these are `forbidden` for students and not executable by anon.
5. **Client.**
   - `QuestionView` gains an optional `onReport`. Null means the action is hidden, so every current caller and all the goldens stay unchanged.
   - Practice passes `onReport`. The quiz screen doesn't.
   - Report notes and teacher notes are plain direction-aware text.

---

### Task 0: Land the plan (Claude)
- [ ] Copy this plan to `docs/superpowers/plans/2026-10-24-p1-c6-review-queue.md` and commit it.

### Task 1: Backend (Codex)

**Create:** the migration and `supabase/tests/39_review_queue.test.sql`. The migration:
- adds the columns, the checks and the partial unique index;
- migrates the existing rows (D2);
- drops the student insert policy;
- adds the setting;
- adds `report_question` and the 4 teacher RPCs.

**Modify:** `docs/07` (the RPC rows and the reason allow-list).

- [ ] **Step 1: Write pgTAP first** for Review focus 1–4.
- [ ] **Step 2: Implement.**
- [ ] **Step 3 (Claude):** push, open a draft PR, get CI `db` green.

### Task 2: Student report action (Codex, after Task 1)

- `lib/shared/widgets/report_problem_sheet.dart`:
  - a bottom sheet under 600 px and a dialog at 600 px and up;
  - the reasons as radio options, plus an optional note with a 500-character counter;
  - Submit / Cancel, and it returns the chosen reason and note.
- `QuestionView`:
  - an optional `onReport` that renders a small "Report a problem" text action under the question body;
  - hidden when `onReport` is null.
- Practice:
  - a `PracticeReportRepository` or a method on the practice repo: `report(questionId, reason, note)`;
  - a cubit method `report(...)`;
  - the SnackBar "Thanks — your teacher will review it." on ok or existing, "Too many reports. Try again in a minute." on `rate_limited`, and mapped copy for other errors.

- [ ] **Step 1: Tests first**:
  - the sheet's validation and its return value;
  - `QuestionView` hides the action when `onReport` is null and shows it when it's set;
  - the cubit `report` on success, existing, rate limit and failure;
  - the practice widget opens the sheet and shows the SnackBar.
- [ ] **Step 2: Implement.**

### Task 3: Teacher review queue (Codex, after Task 2)

- `lib/features/teacher/review/`:
  - the repository (the 4 RPCs);
  - `ReviewQueueCubit` (`load(section)`, paging, `resolve(questionId, outcome, note)`);
  - `ReviewQueueScreen` with two tabs, Reported and Needs review. A row shows the ref, the stem preview, the count, the reason chips and the latest note. A tap opens `/teacher/questions/:id`.
- The editor: a **Reports panel** above the form when the question has open reports. It lists each report's reason, note, date and student, with "Mark fixed" and "Not a problem" (an optional note, then resolve-all).
- `TeacherShell`: a "Review" nav item with a badge from `teacher_review_counts()` (reported + needs_review), refreshed when you go back to it.

- [ ] **Step 1: Tests first**:
  - every cubit method on success and failure;
  - the panel's resolve flow;
  - the badge;
  - no overflow at 360 and 1280;
  - the router: a student going to `/teacher/review` lands on `/`.
- [ ] **Step 2: Implement.**

### Task 4: Gates, review, PR (Claude)

- [ ] `dart format --set-exit-if-changed .`, `flutter analyze --fatal-infos`, `flutter test -j 2 --exclude-tags golden` plus `--tags golden`.
- [ ] Check the diff against Review focus 1–5.
- [ ] STATUS: add the C-6 row. Commit by path and push. **Keep the PR a draft until CI is green**, then mark it ready and say "ready to merge".
- [ ] **Staging check in Chrome (after merge):**
  1. As a student, report a demo question from practice.
  2. As a teacher, find it in Review with the badge showing, open it, and click "Mark fixed".
  3. Check in SQL that `status = resolved_fixed` and that an audit row exists.
  4. Clean up the test report and revert the role.

## Verification

- CI: `db` (pgTAP 39 plus all the existing tests) and `client` green.
- The local gates are green.
- The staging steps above.
