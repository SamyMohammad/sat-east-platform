# Status board

> One place for "where are we". Update it in the same PR that changes a row.
> Start every new session here, then open the linked plan.
> Last updated: 2026-10-19

## Now

| Story / Req | Spec | Plan | Branch | PR | State |
|-------------|------|------|--------|----|-------|
| Lane 1c — catalogue + course page (P-1) | — | — | — | — | next: brainstorm |
| P1 slice staging fixes | — | — | `fix/P1-staging-check` | #34 | open |

## Next — parallel lanes

Up to 3 lanes at once, each in its own `git worktree` branched from `main` (never stacked). Each lane still goes brainstorm → plan → Codex → review → PR.

| Lane | Scope | Write set |
|------|-------|-----------|
| 1 — Student UI (Flutter) | 1a account (#37, done) → 1b activation code + test date (#38, done) → 1c catalogue + course page (P-1). Google sign-in (A-1) deferred | `lib/features/auth`, `lib/features/activation`, `lib/features/catalogue` |
| 2 — Backend only | **Done** (#35, #36) | — |
| 3 — Teacher area (Flutter) | C-1 topics builder, C-7 settings, then C-4/C-5 question import + editor | `lib/features/teacher/*` |

Shared hotspots: `lib/core/di/injection.dart`, `lib/core/router/`, `pubspec.yaml`, migration timestamps, `docs/07` §9 error codes, this file.
- Lanes only append to DI and the router; each plan reserves its migration names and error codes up front.
- Only the router session edits this file, after a merge; other lanes rebase on `main` after each merge and re-run gates.
- Run Flutter gates one lane at a time (`flutter test -j 2`, OOM otherwise). Open a draft PR early so CI runs pgTAP.

Later: L-2/L-3 video + notes, P-2/P-3 Paymob (blocked on Q-03). Phase 1 slice staging check (login → course → topic → practice → quiz → unlock) is the user's.

## Open

| Item | Notes |
|------|-------|
| Pass mark | Teacher Area A design shows 70%, `settings` default is 75% |
| SPR `.0000` | Should trailing zeros grade correct for tiny keys like `1/30000`? |
| Time-up copy | "Your 0 answers…" wording when nothing was answered |
| Restyle | Move to a well-known design system — deferred until after the MVP ships to production |
| Demo course code | Demo course uses code `SAT`. Before real SAT content lands on staging, retire the demo by deleting the CI step "Seed staging demo data" and `supabase/seeds/demo` (or change the demo code) — never edit staging data; re-seeding undoes it and a real `SAT` course breaks every deploy |
| Demo seed in prod | Prod deploy must never run `supabase/seeds/demo` |
| Local `db reset` | Fails with exit 139 at "Initialising schema"; workaround `supabase migration up --local` + restart auth container (`supabase/seeds/demo/README.md`) |
| Quiz follow-ups | Spiral + difficulty blueprint; review-set UI (S-23) and attempt-review UI; quiz repeats on the 12-question demo pools (accepted for the slice) |
| Rate-limit rollback | `private.hit_rate_limit` counts only calls that don't raise (a raise rolls back the increment). Fine for practice/quiz RPCs; guess-style RPCs must return errors instead of raising (lane 1b `redeem_activation_code` does) |
| Auth Site URL | Staging Site URL was the default `localhost:3000` (confirmation link redirected there). Set Site URL + Redirect URLs per `docs/setup/auth.md` §0 — user, staging dashboard; repeat for prod |
| Password reset redirect | Add `<site>/?flow=recovery` to Supabase Redirect URLs on staging and prod (`docs/setup/auth.md` §0) — user |
| Staff course preview | Teachers/admins see `not_enrolled` on Courses (not auto-enrolled); staff preview belongs to the teacher area |
| Local `supabase start` | Also exits 139 on fresh init (Realtime); pgTAP for part 3 ran in a scratch Postgres container — CI is the source of truth |
| register-device Edge Function | register-device Edge Function (App Check) deferred; the client calls the RPC directly |
| Login type size | Login screens use labelLarge 14/600 vs design 13/600 |
| Login a11y | Verify AuthTextField semantics with a screen reader on staging |
| Teacher asks | `15` §0 list — Paymob onboarding, taxonomy, pilot topic block launch more than code |

## Done

| Phase 0 row | Story / Req | PR |
|-------------|-------------|----|
| 1 | F-1 scaffold | — |
| 2 | F-2 hardening + SQL templates | #1 |
| 2b | F-2 schema + settings seed | #3 |
| 3 | F-2 RLS baseline | #4 |
| 4 | GRD-02 SPR grader | #5 |
| 5 | F-3 CI + staging | #6 |
| 6 | F-4 design brief, Claude Design export | #8, #12 |
| 6 | F-4 theme + tokens | #13 |
| 6 | F-4 `MathText` | #15 |
| 6 | F-4 components A — answer inputs | #16 |
| 6 | F-4 components B — buttons + feedback, AppShell | #18, #19 → re-landed in #20 |
| 6 | F-4 `QuestionView` PR 1 — practice + homework | #22 |
| 6 | F-4 `QuestionView` PR 2 — quiz | #23 |
| P1 | Slice 1/5 — staging demo seed | #26 |
| P1 | Slice 2/5 — email login + device limit (staging login check pending, user) | #27 |
| P1 | Slice 3/5 — course map (staging check pending, user) | #29 |
| P1 | Slice 4/5 — practice (staging check pending, user) | #30 |
| P1 | Slice 5/5 — quiz + unlock (staging check pending, user) | #32 |
| — | Auth Site URL setup doc | #31 |
| 6 | F-4 design gallery (staging `#/gallery` checked) — Phase 0 UI exit | #24 |
| Lanes | STATUS parallel lanes | #33 |
| Lane 2a | Expiry cron, rate limits, teacher unlock (LRN-05) | #35 |
| Lane 2b | Review set after a fail (LRN-04), `get_attempt_review` | #36 |
| Lane 1a | Password reset (web), My account, name locked (AUTH-06, AUTH-04) | #37 |
| Lane 1b | Activation code + test date (PAY-06, AUTH-02, PAY-07) | #38 |
| 7–8 | Spikes: encrypted HLS, Paymob | #9 |
| 9–10 | Spike: PDF viewer · F-5 observability | #10 |
| S1 (early) | AUTH-04/05 device limit, PAY-01/04 catalogue backend | #11 |
