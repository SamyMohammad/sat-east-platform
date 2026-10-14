# Status board

> One place for "where are we". Update it in the same PR that changes a row.
> Start every new session here, then open the linked plan.
> Last updated: 2026-10-14

## Now

| Story / Req | Spec | Plan | Branch | PR | State |
|-------------|------|------|--------|----|-------|
| F-4 Components A — answer inputs | [design spec](superpowers/specs/2026-10-13-f4-design-system-questionview-design.md) §2 | [plan](superpowers/plans/2026-10-13-f4-components-inputs.md) | `feat/F-4-components-inputs` | #16 | In review |
| F-4 Components B — buttons + feedback | same §2 | [plan](superpowers/plans/2026-10-14-f4-components-feedback.md) | `feat/F-4-components-feedback` | #18 (on #16) | In review |
| F-4 AppShell | same §2 | [plan](superpowers/plans/2026-10-14-f4-app-shell.md) | `feat/F-4-app-shell` | #19 (on #18) | In review |

## Next

1. F-4 `QuestionView` (practice / homework / quiz / mock modes) — needs its own plan.
2. F-4 component gallery + deploy shell to staging (Phase 0 exit).
3. Phase 1 vertical slice: login → course → topic → practice → quiz → unlock, on staging.
4. Sprint S1 UI (auth, profile, device limit, catalogue, course page) — backend already in PR #11.

## Open

| Item | Notes |
|------|-------|
| PR #14 | Open revert of the theme PR #13 — close it unless the revert is wanted |
| Pass mark | Teacher Area A design shows 70%, `settings` default is 75% |
| SPR `.0000` | Should trailing zeros grade correct for tiny keys like `1/30000`? |
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
| 7–8 | Spikes: encrypted HLS, Paymob | #9 |
| 9–10 | Spike: PDF viewer · F-5 observability | #10 |
| S1 (early) | AUTH-04/05 device limit, PAY-01/04 catalogue backend | #11 |
