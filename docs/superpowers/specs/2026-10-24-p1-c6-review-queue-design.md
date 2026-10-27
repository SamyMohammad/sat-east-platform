# C-6 — question reports + teacher review queue (QB-04, QB-08, T-08) — design

> Status: draft · 2026-10-24 · Branch `feat/P1-c6-review-queue`
> **user** marks a decision the user made (they approved the proposal in chat). Everything else is the router's call.

## Intent

When a student finds a wrong key, a typo or broken math, the teacher should hear about it quickly and fix it in one place. Today `question_reports` exists, but nothing writes to it. There is also a direct student `insert` policy, which has no rate limit and no duplicate check.

## Goals (user approved)

1. **Student report.**
   - A **"Report a problem"** action shows under each question wherever the student is not on a timed run. **Today that means practice only**, because homework and the attempt-review UIs don't exist yet; they reuse the same action when they are built. It is never shown inside a running quiz or mock.
   - The student picks a reason from: "The answer key is wrong", "Typo or unclear wording", "Math doesn't display", "Other". They can add an optional note of up to 500 characters.
   - The student sees "Thanks — your teacher will review it."
   - There is **one open report per student per question**. A second report while one is open returns the existing one (no error).
   - A rate limit applies: `settings.rate_report_per_min` (5).
2. **Teacher review queue** (`/teacher/review`, nav item "Review" with an open-count badge).
   - **Reported:** questions with open reports, **grouped per question**. Each group shows the question's ref and stem preview, the count, the reasons breakdown and the latest note. The most-reported questions come first, then the oldest.
   - **Needs review:** questions with `status = needs_review`, mostly the pipeline's double-solve disagreements.
   - Tapping a question opens the existing editor (`/teacher/questions/:id`) with a **reports panel** that lists that question's open reports.
   - **Resolve:** "Fixed" or "Not a problem" closes **all** open reports on that question at once, with an optional teacher note. `status` gets `resolved_fixed` or `resolved_dismissed`, plus `resolved_at` and `resolved_by`.

## Non-goals

- Notifying the student when the report closes (that comes with notifications, later).
- Report analytics.
- **Regrading past attempts after a key fix.** That is its own story. This one only flags that regrading is not automatic.
- The report action in homework, quiz review or mock review, which don't exist yet.

## Anti-goals

- A student flooding reports, or reporting a question they never saw. The report RPC requires that the question belongs to a topic the student has access to (`has_access_topic`) and that it is `published`.
- A student reading other students' reports. The existing "student selects own" policy stays; the teacher reads them through RPCs.
- Report text being shown as raw HTML or Markdown. It is plain text and direction-aware (rule 8), because notes may be in Arabic.

## Decisions (router's calls)

| # | Decision |
|---|----------|
| D1 | Reports go through an RPC `report_question(p_question_id, p_reason, p_note)` → `{ok:true, report_id, existing:bool}`. **The direct student `insert` policy is dropped**, so the only write path is the RPC. Its reasons come from a fixed allow-list (`answer_key`, `typo`, `math_display`, `other`); anything else → `invalid_input`. |
| D2 | `question_reports` gains `note text` (≤ 500), `resolved_at`, `resolved_by`, `teacher_note`, a `check` on `status in ('open','resolved_fixed','resolved_dismissed')` and on `reason in (...)`, plus a partial unique index on `(question_id, user_id) where status = 'open'`. The existing rows are migrated: `open` stays, anything else → `resolved_dismissed`. |
| D3 | Teacher RPCs: `teacher_list_review_queue(p_section text /* reported|needs_review */, p_page int)` (paged by `settings.bank_page_size`), `teacher_list_question_reports(p_question_id)`, `teacher_resolve_reports(p_question_id, p_outcome text, p_note text)` → `{closed: n}` with one audit row, and `teacher_review_counts()` → `{reported, needs_review}` for the badge. |
| D4 | The student-facing copy and the reason labels live in the practice feature. The report sheet is a small shared widget in `lib/shared/widgets/`, because practice, homework and the reviews will all use it (rule A.2). `QuestionView` gains an optional `onReport` callback (default null = hidden), and the shared widget renders the action. |
| D5 | The rate limit uses the existing `private.hit_rate_limit` and **returns** `{ok:false, error:'rate_limited'}` instead of raising, per the STATUS note on raise rollback. |

## Constraints

- CLAUDE.md rules 1–10, A, B; `docs/16` §2; SQL from templates; the pgTAP `reset role` rule; no `$$` inside function bodies.
- pgTAP:
  - A report on an accessible published question → ok. On a question with no access, or one that isn't published → `invalid_input`.
  - A duplicate open report → `existing:true`, with no new row. After it's resolved, a new report is allowed.
  - The rate limit.
  - A direct insert as a student now fails.
  - Resolve closes all open reports of that question and only those, and writes an audit row.
  - Queue ordering and paging; the counts.
  - Every teacher RPC is `forbidden` for students and not executable by anon.
- The PR stays a **draft until CI is green**.

## Left to the builder

- The report sheet layout (bottom sheet on phone, dialog at ≥ 600 px).
- The queue table layout, following `Teacher Area B.dc.html` T-08 if present; otherwise it reuses the bank table style.
