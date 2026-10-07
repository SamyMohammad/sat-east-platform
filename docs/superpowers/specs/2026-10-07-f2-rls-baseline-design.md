# F-2 row 3 — RLS baseline (design)

Story: docs/15 §1 row 3 (F-2, NFR-07, NFR-08). Source of truth: `docs/06` §4 (matrix + helpers +
traps), `docs/16` §1 (Layer 4).

## Goal
Open exactly the data each role needs and nothing else, prove it with tests, and make "a public
table without RLS or a policy" fail the build.

## Scope
**In:**
- Helpers `public.is_teacher()`, `public.has_access(uuid)`, `public.has_access_topic(uuid)`.
- Grants + policies for all 42 public tables per `docs/06` §4 (teacher all; student/anon rows).
- The four row-2b traps (`docs/06` §4).
- Indexes on every `user_id` / `thread_id` FK a "select own" policy filters on.
- `supabase_test_helpers` (pinned, vendored) for the tests.
- pgTAP: helpers, per-table access (student A vs B, teacher, anon), traps, Layer-4 gate.
- Script: `private` is not reachable through the REST API.

**Out:** device check in `has_access` (device story, S1); RPCs (`check_practice_answer`,
`submit_attempt` …); CI wiring (row 5 runs the tests and the script).

## Decisions (agreed 2026-10-07)
1. Teacher = one `for all` policy per table using `(select public.is_teacher())`; `audit_log` is
   select-only for teachers.
2. Anon reads the published catalogue (PAY-01): courses, units, topics, subtopics, active prices.
3. Students never read the question bank tables directly; RPCs only (anti-scraping, rule 1).
4. `ai_*` select-only for students; writes go through the `ai-tutor` EF.
5. Column-level grants: `profiles` update (6 editable columns), `notifications` update (`read_at`),
   `orders` select (all columns except `raw_payload`).
6. `attempt_answers` select own only when the parent attempt's status is not `in_progress`.
7. Helpers are `security definer`, `stable`, `set search_path = ''`, `language sql`, granted to
   `authenticated` (and `anon` only where an anon policy needs them — none do).
8. `supabase_test_helpers` vendored as a pinned SQL file run first by `supabase test db`; never in
   `migrations/`.
9. Test `04_schema_locked` (row 2b) is replaced by the Layer-4 gate + per-table access tests.
10. Grant model: `authenticated` gets DML on every public table (the teacher is `authenticated`);
    RLS is the student gate; column grants (decision 5) apply to the teacher too, so
    `orders.raw_payload` and `profiles.role` are changed only from the dashboard (user-approved).

## Files
| File | Content |
|------|---------|
| `supabase/migrations/<ts>_f2_rls_helpers.sql` | 3 helpers + grants |
| `supabase/migrations/<ts>_f2_rls_policies.sql` | grants, policies, indexes for all tables |
| `supabase/tests/000_test_helpers.sql` | vendored `supabase_test_helpers` (pinned version) |
| `supabase/tests/04_rls_gate.test.sql` (replaces `04_schema_locked`) | Layer 4: every public table has RLS + ≥1 policy; no views in public; anon/authenticated have no privileges on `private` |
| `supabase/tests/07_rls_helpers.test.sql` | `is_teacher`, `has_access` (active / expired / suspended / none), `has_access_topic` (free preview, unpublished) |
| `supabase/tests/08_rls_identity.test.sql` … `1x_rls_<area>.test.sql` | one file per area of the matrix (identity, catalogue, content, attempts/progress, AI/comms) |
| `scripts/api-private-check.ps1` | `GET /rest/v1/question_keys` with header `Accept-Profile: private` → expect HTTP 406 |

## Error handling
Policies deny silently (empty result) for select; writes outside policy fail with `42501`. Tests
assert both. No new `docs/07` §9 codes.

## Testing / done
`scripts/db-reset.ps1` + `scripts/db-test.ps1` green; `scripts/api-private-check.ps1` passes;
`supabase db lint` and advisors show no new findings (the row-2b "RLS enabled, no policy" notices
disappear); template checklist walked.

## Risks
- Policy helpers called per row → wrap in `(select …)` so Postgres evaluates them once (16 §2 #3).
- Teacher `for all` on `orders`/`enrollments` lets a teacher edit payment rows by hand; accepted
  (single teacher-owner); audit trail comes with the payments story.
