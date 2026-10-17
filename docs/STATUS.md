# Status board

> One place for "where are we". Update it in the same PR that changes a row.
> Start every new session here, then open the linked plan.
> Last updated: 2026-10-17

## Now

| Story / Req | Spec | Plan | Branch | PR | State |
|-------------|------|------|--------|----|-------|
| P1 part 5 — quiz + unlock (slice 5/5) | [spec](superpowers/specs/2026-10-17-p1-quiz-design.md) | [plan](superpowers/plans/2026-10-17-p1-quiz.md) | `feat/P1-quiz` | #32 | in review |

## Next

1. Phase 1 vertical slice: finish the staging check after #32 merges (login → course → topic → practice → quiz → unlock).
2. Sprint S1 UI (auth, profile, device limit, catalogue, course page) — backend already in PR #11.

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
| Quiz follow-ups | Spiral + difficulty blueprint, answer review (`get_attempt_review`), targeted review set after a fail, `cron-expire-attempts`; quiz repeats on the 12-question demo pools (accepted for the slice) |
| Practice rate limiting | `private.hit_rate_limit` (`docs/16`) not built; practice RPCs unthrottled |
| Abandoned practice attempts | In-progress practice attempts are never closed; cleanup job later |
| Auth Site URL | Staging Site URL was the default `localhost:3000` (confirmation link redirected there). Set Site URL + Redirect URLs per `docs/setup/auth.md` §0 — user, staging dashboard; repeat for prod |
| Staff course preview | Teachers/admins see `not_enrolled` on Courses (not auto-enrolled); staff preview belongs to the teacher area |
| Local `supabase start` | Also exits 139 on fresh init (Realtime); pgTAP for part 3 ran in a scratch Postgres container — CI is the source of truth |
| Manage devices | Manage-devices page + list-my-devices RPC deferred |
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
| 6 | F-4 design gallery (staging `#/gallery` checked) — Phase 0 UI exit | #24 |
| 7–8 | Spikes: encrypted HLS, Paymob | #9 |
| 9–10 | Spike: PDF viewer · F-5 observability | #10 |
| S1 (early) | AUTH-04/05 device limit, PAY-01/04 catalogue backend | #11 |
