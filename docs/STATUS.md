# Status board

> One place for "where are we". Update it in the same PR that changes a row.
> Start every new session here, then open the linked plan.
> Last updated: 2026-10-26

## Now — closed beta prep

Code for the closed beta (activation codes, no Paymob) is done and staging-checked. What is left is setup and content.

| Item | Owner | State |
|------|-------|-------|
| Prod Supabase project (Free for beta) + GitHub environments, vars, secrets — [prod runbook](setup/prod.md) | user | to do |
| First prod deploy (`Deploy prod` workflow) + restore drill | router + user | after the prod project exists |
| Teacher taxonomy loaded into `skills`; first real topics (videos, notes, questions) | teacher | waiting |
| Retire the demo seed before real SAT content (see Open: Demo course code) | router | when content arrives |
| Staging: Confirm email OFF for the beta (no SMTP yet) | user | check |

## Next — after launch

Deferred for the closed beta (user, 2026-10-25): Paymob (P-2/P-3, blocked on Q-03), SMTP emails (Resend), coupons, live sessions, announcements, completion matrix (ANL-05), quiz spiral + difficulty blueprint, homework E/M/H blueprint, Google sign-in (A-1), free-topic access without enrolment.

### How we work (lanes)
Up to 3 lanes at once, each in its own `git worktree` branched from `main` (never stacked). Each lane goes brainstorm → plan → Codex → review → PR.

Shared hotspots: `lib/core/di/injection.dart`, `lib/core/router/`, `pubspec.yaml`, migration timestamps, `docs/07` §9 error codes, this file.
- Lanes only append to DI and the router; each plan reserves its migration names and error codes up front.
- Only the router session edits this file, after a merge; other lanes rebase on `main` after each merge and re-run gates.
- Run Flutter gates one lane at a time (`flutter test -j 2`, OOM otherwise). Open a draft PR early so CI runs pgTAP.

## Open

| Item | Notes |
|------|-------|
| Restyle | Move to a well-known design system — deferred until after the MVP ships to production |
| Demo course code | Demo course uses code `SAT`. Before real SAT content lands on staging, retire the demo by deleting the CI step "Seed staging demo data" and `supabase/seeds/demo` (or change the demo code) — never edit staging data; re-seeding undoes it and a real `SAT` course breaks every deploy |
| Demo seed in prod | Prod workflow has no seed step, guards demo seed paths and asserts prod/staging refs differ (`.github/workflows/deploy-prod.yml`) |
| Prod backups | Nightly encrypted R2 backups and backup-before-migrate; owner setup + restore drill: [prod runbook](setup/prod.md) |
| Local `db reset` | Fails with exit 139 at "Initialising schema"; workaround `supabase migration up --local` + restart auth container (`supabase/seeds/demo/README.md`) |
| Quiz follow-ups | Spiral + difficulty blueprint; review-set UI (S-23); link the quiz result to the shared attempt report (#57 built it for homework; the quiz result screen has no attempt id yet); quiz repeats on the 12-question demo pools (accepted for the slice) |
| Rate-limit rollback | `private.hit_rate_limit` counts only calls that don't raise (a raise rolls back the increment). Fine for practice/quiz RPCs; guess-style RPCs must return errors instead of raising (lane 1b `redeem_activation_code` does) |
| Auth Site URL | Staging done (2026-10-24). Prod: set Site URL + Redirect URLs per `docs/setup/auth.md` §0 — user, part of the [prod runbook](setup/prod.md) |
| Password reset redirect | Staging done (2026-10-24). Prod: add `<site>/?flow=recovery` (`docs/setup/auth.md` §0) — user |
| Free topic access | Course page shows a Free badge only; opening a free topic without an enrolment is its own later story (user, 2026-10-19) |
| Skill taxonomy | Import rejects unknown skill codes; the teacher's taxonomy (`docs/09` §4) must be loaded into `skills` before real imports |
| Regrade after key fix | Fixing a key (editor / review queue) does not regrade past attempts; its own story |
| Staff course preview | Teachers/admins see `not_enrolled` on Courses (not auto-enrolled); staff preview belongs to the teacher area |
| Local `supabase start` | Also exits 139 on fresh init (Realtime); pgTAP for part 3 ran in a scratch Postgres container — CI is the source of truth |
| register-device Edge Function | register-device Edge Function (App Check) deferred; the client calls the RPC directly |
| Login type size | Login screens use labelLarge 14/600 vs design 13/600 |
| Login a11y | Verify AuthTextField semantics with a screen reader on staging |
| Video CLI on Windows | Scoop's ffmpeg shim fails on the dev machine; prepend `%LOCALAPPDATA%\Microsoft\WinGet\Links` to PATH before `tools/video-pipeline` |
| Teacher asks | `15` §0 list — Paymob onboarding, taxonomy, pilot topic block launch more than code |

## Done

| Phase 0 row | Story / Req | PR |
|-------------|-------------|----|
| P1 | Staging-check polish: no lost video seconds, whole percents, MB quota, report rows | #60 |
| P1 | Trim EF video secrets (staging R2 key had a stray character) | #59 |
| P1 | Prod deploy (manual) + nightly encrypted backups to R2 + prod runbook | #58 |
| P1 | Homework (PRC-02, PRC-05, ANL-02) + shared attempt report, staging-checked | #57 |
| L-2c | Video client: player, watermark, progress, teacher Videos screen (LRN-02, SEC-01, C-2), staging-checked | #56 |
| L-2b | Video publish CLI + presigned uploads (C-2) | #54, #55 |
| L-2a | Protected video server (SEC-01, LRN-02) | #53 |
| C-6 | Question reports + review queue (QB-04, QB-08), staging-checked | #52 |
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
| Lane 1c | Catalogue + course page (P-1, PAY-01) | #39 |
| L-3 | Protected notes + teacher upload (SEC-02, C-3), staging-checked; finished students exempt from the notes gate | #50, #51 |
| Lane 3c-2 | Question bank + editor (C-5, QB-06), staging-checked; editor polish, LaTeX-$ guard | #46, #47, #49 |
| — | Open product questions settled: pass mark 75, SPR zero fill, zero-answer copy | #48 |
| Lane 3c-1 | Question import (C-4, QB-05), staging-checked | #44, #45 |
| Lane 3b | Teacher settings (C-7, ADM-06), staging-checked | #42, #43 |
| Lane 3a | Teacher area + course builder (C-1, ADM-01), staging-checked | #40, #41 |
| Lane 1b | Activation code + test date (PAY-06, AUTH-02, PAY-07) | #38 |
| 7–8 | Spikes: encrypted HLS, Paymob | #9 |
| 9–10 | Spike: PDF viewer · F-5 observability | #10 |
| S1 (early) | AUTH-04/05 device limit, PAY-01/04 catalogue backend | #11 |
