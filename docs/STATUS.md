# Status board

> One place for "where are we". Update it in the same PR that changes a row.
> Start every new session here, then open the linked plan.
> Last updated: 2026-10-16

## Now

| Story / Req | Spec | Plan | Branch | PR | State |
|-------------|------|------|--------|----|-------|
| P1 part 1 — demo seed (slice 1/5) | [spec](superpowers/specs/2026-10-16-p1-slice-demo-seed-design.md) | [plan](superpowers/plans/2026-10-16-p1-demo-seed.md) | `feat/P1-demo-seed` | — | in progress |

## Next

1. Phase 1 vertical slice: login → course → topic → practice → quiz → unlock, on staging.
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
| 6 | F-4 design gallery (staging `#/gallery` checked) — Phase 0 UI exit | #24 |
| 7–8 | Spikes: encrypted HLS, Paymob | #9 |
| 9–10 | Spike: PDF viewer · F-5 observability | #10 |
| S1 (early) | AUTH-04/05 device limit, PAY-01/04 catalogue backend | #11 |
