# Lane 1b — activation code + test date — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A signed-in student with no course redeems a teacher's activation code and picks a test date; the server creates the enrolment and its access window; My account shows the course, test date and access end.

**Architecture:** One migration (settings, `redeem_activation_code`, `private.generate_activation_codes`). New client feature `lib/features/activation` (data → domain → presentation) with an `/activate` route reached from the course map's "No course yet" state; the account screen gains a read-only Course section via the existing `enrollments` RLS.

**Tech Stack:** Postgres/pgTAP, Flutter (Cubit, go_router, get_it, supabase_flutter).

**Spec:** `docs/superpowers/specs/2026-10-18-p1-lane1b-activation-design.md` (approved).

**Context:** Lane 1, PR 1b. Lane 1a (#37) and lane 2 (#35, #36) are merged. Worktree `C:/Users/Lenovo/sat-wt-lane1b`, branch `feat/P1-lane1b-activation` (spec + STATUS commits on it). Codex implements in the lane-1 Codex session (`01a14c3e-…`, `--cd C:/Users/Lenovo/sat-wt-lane1b`); Codex cannot run Docker or Flutter, so Claude runs the Flutter gates locally and CI runs pgTAP on a draft PR.

## Global Constraints

- CLAUDE.md rules 1–10, A, B; `docs/16` §2; SQL from `supabase/templates/`.
- Settings (seed `on conflict (key) do nothing`): `access_grace_days` 14, `access_min_days` 60, `test_date_max_days` 548, `rate_redeem_per_min` 5.
- Error codes: new `code_invalid`, `code_used`, `already_enrolled` (docs/07 §9 + `ErrorCodes`). Guess failures are **returned** as `{ok:false, error}`; `not_authenticated`, `invalid_input`, `rate_limited` are raised.
- Reserved: migration `20261018400000_lane1b_activation.sql`, pgTAP `31_activation.test.sql`, route `/activate`, feature folder `lib/features/activation`.
- Exact copy from spec §4. Lint rules: `package:` imports, sorted directives, ≤ 80 chars, inferred locals, `--fatal-infos`.
- Codex does not commit.

## Review Focus

1. Wrong code guesses count toward the rate limit (6th wrong guess in a minute → `rate_limited`) — pgTAP test.
2. Two students redeem the same code at once → one enrolment, the other gets `code_used` (row lock) — pgTAP test.
3. A failed redeem (`already_enrolled`) leaves the code unredeemed — pgTAP test.
4. Code typed in lower case with dashes/spaces redeems — pgTAP + client passes the raw text (server normalises).
5. After success the router lands on the course map, which now loads (not "No course yet") — cubit/router test.

---

### Task 0: Land the plan (Claude)
- [ ] Copy to `docs/superpowers/plans/2026-10-18-p1-lane1b-activation.md`, commit.

### Task 1: Backend (PAY-06, PAY-07)

**Files:** create the migration + `31_activation.test.sql`; modify `docs/07` (RPC row, §5 `redeem-code` → RPC, §7 access window wording, §9 codes), `docs/05` §7, `docs/16` §8 (drop `redeem-code` from Edge Function lists); create `docs/setup/activation-codes.md` (one-line SQL to generate codes for a course + how to list unused codes).

**Interfaces (Produces):**
- `public.redeem_activation_code(p_code text, p_target_test_date date) returns jsonb` → `{ok:true, course_id, course_slug, course_title, target_test_date, expires_at}` or `{ok:false, error}`.
- `private.generate_activation_codes(p_course_id uuid, p_count int, p_note text) returns setof text` (12 chars from `ABCDEFGHJKMNPQRSTUVWXYZ23456789`).

- [ ] **Step 1: Tests** — happy path (row values, `expires_at` both `greatest` branches: near date → `now()+60d`, far date → `date+15` days at 00:00 UTC); code marked redeemed by caller; normalisation; `code_invalid` (unknown, unpublished course); `code_used`; `already_enrolled` leaves code unused; date today−2 / today+549 → `invalid_input`, today−1 and today OK; Review Focus 1–3; anon → no execute; `authenticated` cannot execute the generator; generator returns N unique 12-char codes in the alphabet.
- [ ] **Step 2: Implement** per spec §3 (lock code `for update`; one transaction).
- [ ] **Step 3: Verify (Claude)** — push, draft PR, CI `db` green.

### Task 2: Client activation flow (S-10)

**Files:** create `lib/features/activation/{data,domain,presentation}/…` (remote data source, repository + interface, `ActivationResult` entity, `ActivationCubit`/state, `ActivateScreen`, copy); modify `lib/core/errors/error_codes.dart` (+3 server codes), `lib/core/router/app_router.dart` (`/activate`, signed-in only), `lib/features/course_map/presentation/screens/course_map_screen.dart` (not-enrolled empty state gets "Enter activation code" → `/activate`), `lib/core/di/injection.dart` (append); tests mirroring each file.

**Interfaces:**
- `ActivationRepository.redeem(String code, DateTime testDate) → Future<Result<ActivationResult>>`; data source maps `{ok:false,error}` → `Failure(AppError(error))` and raised `PostgrestException` via the shared mapper; sends the date as `yyyy-MM-dd`.
- `ActivationCubit.submit(String code, DateTime testDate)`; states sealed: `ActivationIdle`, `ActivationSubmitting`, `ActivationDone(ActivationResult)`, `ActivationFailed(AppError)`.
- Screen: code field + date picker (first date = local today, last = today + 548 days) + "Activate"; success → `context.go('/')` and the course map reloads.

- [ ] **Step 1: Tests** — data source (success, each returned error, raised rate_limited/network), repository, every cubit method success + failure, widget (validation, picker bounds, error copy per code, success navigation), router (`/activate` signed-out → sign-in), course map empty-state action.
- [ ] **Step 2: Implement.**
- [ ] **Step 3: Verify (Claude)** — `dart format`, `flutter analyze --fatal-infos`, `flutter test -j 2`.

### Task 3: My account — Course section (AUTH-02)

**Files:** modify `lib/features/auth` account data/domain/presentation (repository method `listMyEnrollments`, entity `MyEnrollment{courseTitle, targetTestDate?, expiresAt, isExpired}`, `AccountCubit.load` includes it, `AccountScreen` section), tests.

- Query: `enrollments.select('target_test_date, expires_at, status, courses(title)')` for the caller (RLS), ordered by `expires_at desc`.
- Copy: section "Course"; rows "Test date", "Access until" / "Access ended"; note "Contact your teacher to change your test date."; no enrolment → section hidden.

- [ ] **Step 1: Tests** — data mapping (null date, expired), cubit load with/without enrolments + failure, widget rows and note.
- [ ] **Step 2: Implement.**
- [ ] **Step 3: Verify (Claude)** — gates; mark PR ready.

## Verification (end to end)

- CI green on the PR (db + client).
- After merge (user, staging): run the SQL from `docs/setup/activation-codes.md` to make one code for the demo course; sign up a fresh account → course map shows "No course yet" → Enter activation code → code + date → map opens; Profile shows the Course section; the same code on a second account → "That code has already been used."
