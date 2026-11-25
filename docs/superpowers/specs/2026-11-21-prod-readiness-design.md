# Production readiness — closed beta (web), $0 infra

## Context
Goal: get the platform ready for its first real students (closed beta, web only, activation codes, no Paymob, no mobile stores) while keeping security, performance, monitoring and fast CI/CD. `docs/STATUS.md` already has an R0–R4 roadmap; this plan supersedes its R0/R1/R4-ops parts for the beta and reorders them into phases. A read-only audit (2026-11-21) against `docs/10` NFRs, ADR-008/009, `docs/12`, `docs/16` found the gaps listed per phase below.

Decisions (owner, grill session 2026-11-21):
- Target: closed beta, web. Mobile (R3), Paymob, App Check client stay later.
- Budget **$0**: Supabase Free (no Pro, no PITR), every tool on a free tier; work around Free limits.
- No domain: app on `*.pages.dev`. Auth mail via **Brevo free SMTP** (single verified sender, 300/day). Confirm email stays OFF; Turnstile guards sign-up.
- Cohort 50–300 students → design around Free limits (500 MB DB, 5 GB egress, 1 GB storage) with alerts + a documented upgrade trigger.
- Alerts: Healthchecks.io (dead-man for backup + keep-alive) + UptimeRobot (app + API) + Sentry → **email + Telegram**.
- Sequencing: finish VID-01 first, then hardening runs as its own lane (worktree) beside feature lanes.
- ffmpeg core: **jsDelivr pinned `@ffmpeg/core@0.12.10` + SHA-256 check** in the client (32 MB > Pages 25 MiB/file limit).
- CI: quick wins, target PR ≤ 4 min.
- Privacy: Privacy + Terms pages on landing + admin-only `admin_delete_student` RPC.
- Notes egress: client-side PDF cache now; move notes to R2 only if the egress alert fires.
- Process: this grill = the brainstorm. One spec, one plan file per phase, Sonnet `implementer` per task, router reviews diffs + runs gates, one PR per phase. Fresh brainstorm only for the blanket-grant revoke and `admin_delete_student`.

## Token / quality rules for execution
- Write `docs/superpowers/specs/2026-11-21-prod-readiness-design.md` (this decision list + gap table) and per-phase plans `docs/superpowers/plans/2026-11-2x-prod-P<n>.md`.
- Implementer briefs point at plan file + task number + files; never paste content. Independent tasks in parallel worktrees; same-file tasks serial (`ci.yml`, `_headers`, `injection.dart` are hotspots).
- Router reviews: `git diff --stat` → changed hunks only → gates (`dart format`, `flutter analyze --fatal-infos`, `flutter test -j 2`, `scripts/db-test.ps1` / CI pgTAP, `deno test`). Draft PR early so CI runs pgTAP.
- `/flutter-code-quality:review-gate` + `/flutter-code-review` per Flutter-touching PR; `git-expert` for branch/commit/PR.

## P0 — Close VID-01 (current branch)
1. Remove `apps/client/web/vendor/ffmpeg-core-0.12.10/*.wasm` (and the core JS) from the branch *and its commits* (rewrite branch before merge so 32 MB never lands in `main` history).
2. Load core + wasm from `https://cdn.jsdelivr.net/npm/@ffmpeg/core@0.12.10/dist/esm/` (checked 2026-11-21: 200, wasm 32,232,419 bytes served in full); fetch → verify SHA-256 against constants → `toBlobURL`. Mismatch → `AppError` (new code in `docs/07` §9), teacher sees English copy. Test the hash check in the data layer.
3. GPL note in ADR-002 (unmodified upstream build served from jsDelivr).
4. Remaining VID-01 items from STATUS: R2 CORS `PUT`, YouTube row-count check before applying migration on staging, manual browser check. Merge.

## P1 — Guardrails + CI speed (repo-only, no accounts)
1. CI quick wins in `.github/workflows/ci.yml` (lands **before** branch protection):
   - `dorny/paths-filter` with job-level `if`, applied on `pull_request` only — `main` pushes always run every job (`deploy` needs all three; a skipped `client` would skip staging deploy). SQL/docs-only PRs skip Flutter; Dart-only PRs skip db. Client filter includes `supabase/tests/**` (`spr_answer_test.dart` reads it).
   - Aggregator job `ci-ok` (`needs:` all jobs, `if: always()`, fails on any `failure`/`cancelled`) — the only required check, so skipped/matrix jobs never hang.
   - Split `flutter test` into 3 shards (`--total-shards 3 --shard-index n`, matrix); `flutter build web` + secret-grep in its own job parallel to tests.
   - `timeout-minutes` on every job in `ci.yml`, `keep-alive.yml`; fix stale "skipped while none exist" label.
   - `deploy-prod.yml` / `backup-prod.yml`: replace from-scratch PGDG/psql/awscli installs with what the runner has, or cache the debs.
2. Branch protection on `main` (repo is public → free): required check `ci-ok`; no force-push. Fix the drift: `ci.yml:2` comment, `docs/16` §7 "private repo", `docs/12` §4.
3. Dependabot (`github-actions`, `pub` in `apps/client`, `npm` in `apps/landing`; weekly, grouped), `CODEOWNERS`, `SECURITY.md`.
4. `scripts/secret-grep.sh`: add patterns for Groq/Cloudflare/R2/Brevo/Sentry auth tokens (+ its test in `scripts/tests/`).
5. Scheduled workflow (weekly) warning when `SUPABASE_ACCESS_TOKEN` expiry (2027-01-05) is < 21 days — fails the run so the email arrives.

## P2 — Prod alive and recoverable on Free
User first: restore `sat-prod`, add prod + prod-backup secrets (`docs/setup/prod.md`), create Healthchecks.io + UptimeRobot + Telegram bot.
1. `keep-alive.yml`: add prod (Free pauses after 7 idle days); ping a Healthchecks.io check on success.
2. `backup-prod.yml`: Healthchecks `/start`, success, `/fail` pings; separate backups bucket from the video bucket (R0 item).
3. Weekly question-bank export (NFR-19) as a step in the backup workflow (CSV/JSON of questions + `private.question_keys`, encrypted like the dump).
4. Restore drill script `scripts/restore-drill.ps1` (download → decrypt → restore into local Postgres container → row-count sanity) + run it once; record in `docs/setup/prod.md` §7.
5. Free-limit watch: weekly workflow running SQL (`pg_database_size`, `sum(storage.objects size)`) → fail above 70 % of 500 MB / 1 GB. Egress isn't queryable → owner turns on Supabase usage emails; document the upgrade trigger (any metric > 80 % or cohort > 300 → Pro).

## P3 — Security hardening
1. `apps/client/web/_headers` + `apps/landing/_headers`: CSP covering self, Supabase URL + `wss:` (Realtime), Sentry ingest, PostHog host, jsDelivr, `*.r2.cloudflarestorage.com` (presigned PUT/GET) + video playback host, Turnstile, `blob:` for `worker-src`/`media-src`, `wasm-unsafe-eval`; CanvasKit either allow `www.gstatic.com` or build with `--no-web-resources-cdn`. Plus HSTS, `X-Content-Type-Options`, `frame-ancestors 'none'`, `Referrer-Policy`, `Permissions-Policy`. **No COEP** (breaks jsDelivr/R2/Supabase fetches; single-thread core doesn't need it). Ship as `Content-Security-Policy-Report-Only` on staging with reports to Sentry's security endpoint; enforce after one clean staging pass (boot, video play, upload, notes, login).
2. Turnstile captcha: Supabase auth captcha (prod + staging) + client widget on sign-up / login / reset (web JS interop, data layer passes token). Tests for the data source. Before enabling on staging, grep `scripts/`, `tools/`, k6/Postman for non-interactive password logins (k6 mints JWTs — expected fine).
3. Auth settings: min password 8 + letters/digits, Brevo SMTP on prod, Site URL/redirects (`docs/setup/auth.md` §0). Mirror into `supabase/config.toml` where it applies locally.
4. **Decided: option A (2026-11-25).** Revoke the blanket `authenticated` DML grant (`f2_rls_policies.sql:9`) in a new migration; the client writes no table directly, so there is no allow-list: `authenticated`/`anon` are read-only on `public`. pgTAP invariant in `supabase/tests/55_no_client_write_grants.test.sql`.
5. Enforce `device_header_required` on prod settings (R0).
6. NFR-07 client test: assert practice/quiz/mock fetch payload models never contain key/explanation fields before submit.
7. **(brainstorm)** Privacy + Terms static pages on landing (owner/lawyer reviews text), link from sign-up; `admin_delete_student` RPC (admin only, audit-logged, removes PII, keeps anonymised attempts) + pgTAP + teacher-area button.

## P4 — Monitoring
1. Sentry release = git SHA in `configureSentry` (`sentry_error_reporter.dart`) + `--source-maps` build, upload with `sentry-cli` in CI, then delete `*.map` from `build/web` before deploy. DSN for staging (`ci.yml` jq) and prod (`deploy-prod.yml`); `SENTRY_DSN_EF` secret on both projects. `tracesSampleRate` 0.05.
2. Health endpoint in `supabase/functions/api` (`verify_jwt = false` already, `config.toml:385`): `GET /health` → DB ping, no auth, no data, rate-limited. UptimeRobot on app URL + `/health` every 5 min — this also keeps prod from pausing, so once live it replaces the P2.1 prod keep-alive (one mechanism, one alert).
3. Sentry alert rules (new issue, spike) → email + Telegram; document in `docs/setup/observability.md`.
4. PostHog NFR-18 events stay in **lane C** (feature lane); P4 only checks CSP + DSN wiring for it.

## P5 — Performance
1. Cache headers in `_headers`: `no-cache` for `index.html`, `flutter_bootstrap.js`, `version.json`, `flutter_service_worker.js`, `main.dart.js` (unhashed); long `immutable` for `canvaskit/*`, `assets/fonts/*`, vendored versioned files.
2. Deferred imports for the teacher area and quiz/mock routes (`app_router.dart:25-44`) per NFR-03; measure `main.dart.js` size before/after.
3. Notes PDF client cache keyed by (asset id, version) — skip re-download of the signed URL.
4. k6 load run on staging (`load-staging.yml`, needs `STAGING_JWT_SECRET` from owner) → compare with NFR-01/02 p95, top 10 `pg_stat_statements` → fix indexes if needed.

## P6 — Go-live
1. First `Deploy prod` run; prod Site URL/redirects; Brevo test mail; Turnstile on prod.
2. Smoke on prod: sign-up with activation code, practice, quiz, mock, video, notes, reset password; Sentry test event; UptimeRobot + Healthchecks green.
3. Retire demo seed before real content (STATUS Open).
4. Update `docs/STATUS.md` (replace R0/R1/R4-ops rows), go-live checklist in `docs/setup/prod.md`.

## Owner actions (can't be done by code)
Confirm `sat-prod` is still restorable (Free projects paused > 90 days can't be restored from the dashboard — else create a new one and update GitHub prod vars) · restore `sat-prod` · prod secrets · Brevo account + verified sender · Turnstile site key (pages.dev hostnames) · Healthchecks.io + UptimeRobot + Telegram bot · `STAGING_JWT_SECRET` · Supabase usage emails · Privacy/Terms text review · renew `SUPABASE_ACCESS_TOKEN` before 2027-01-05.

## Verification
Per phase: CI green on the PR (all shards, db pgTAP, functions), router-run local gates, staging deploy after merge and a manual staging check of the touched flow (CSP console clean, upload/playback, login with captcha). P1: measured PR CI time ≤ 4 min on a Dart PR and a SQL-only PR; a deliberately failing check blocks merge. P2: a forced backup failure reaches Telegram; restore drill row counts match. P4: test error appears in Sentry with readable Dart stack + release SHA; stopping keep-alive triggers a Healthchecks alert. P6: prod smoke list passes.
