# P4 — Monitoring (code part)

Spec: `docs/superpowers/specs/2026-11-21-prod-readiness-design.md` (P4). Owner-side steps
(Sentry account, UptimeRobot monitors, alert rules) are in `docs/setup/observability.md`.
Everything here must be **inert when its secret/variable is missing** (no Sentry account yet).

## Task 1 — Sentry release + source maps (client)
- `configureSentry` gets a `release` param; set `options.release` when non-empty, and
  `tracesSampleRate = 0.05` when a DSN is set (keep `0` otherwise). New define
  `SENTRY_RELEASE` in `lib/core/env/env.dart` (empty default); `main.dart` passes it.
- Unit test in `test/core/observability/` for `configureSentry` (release set / unset, sample rate).
- `.github/workflows/ci.yml` staging build and `deploy-prod.yml`:
  - `SENTRY_DSN: ${{ vars.STAGING_SENTRY_DSN }}` (prod already has `PROD_SENTRY_DSN`) and
    `SENTRY_RELEASE: ${{ github.sha }}` added to the jq env JSON.
  - `flutter build web --release --source-maps ...`.
  - New step after the build: if `secrets.SENTRY_AUTH_TOKEN` and `vars.SENTRY_ORG` are set,
    `npx -y @sentry/cli@<pinned> sourcemaps upload --org ... --project client --release $SHA build/web`;
    else print a notice and skip. **Always** then `find build/web -name '*.map' -delete`
    (maps never ship to Pages), before secret-grep and deploy.
- CSP: confirm the Sentry ingest host is allowed in `apps/client/web/_headers` connect-src
  (`https://*.ingest.sentry.io` / `*.ingest.de.sentry.io`); add if missing.

## Task 2 — `GET /health` on the `api` Edge Function
- Route in `supabase/functions/api/app.ts`: no auth, no App Check, returns
  `{ ok: true }` 200 when a DB ping succeeds, `{ ok: false }` 503 otherwise. No data, no
  version info, `cache-control: no-store`. DB ping via a new `Deps.ping(): Promise<boolean>`
  (index.ts: anon client `rpc('health_ping')` or a cheap select that needs no grants).
  - If an RPC is needed: migration `public.health_ping() returns boolean` (security invoker,
    `select true`), from `supabase/templates/`, `grant execute ... to anon, authenticated`,
    pgTAP test.
- Rate limit: the route must not do more than one DB ping per 10 s per isolate (cache the
  last result with its timestamp using `Deps.now`) — UptimeRobot hits it every 5 min.
- Deno tests in `app_test.ts`: 200 ok, 503 when ping fails/throws, cache reuses result
  within 10 s, no auth header needed.

## Task 3 — Turnstile language
- Turnstile renders in the browser language (seen Arabic on staging). Product is English
  only (CLAUDE.md rule 8): pass `language: 'en'` in the render options
  (`lib/core/captcha/turnstile_captcha_web.dart`).

## Task 4 — Docs
- `docs/setup/observability.md`: Sentry org/projects, `STAGING_SENTRY_DSN` var,
  `SENTRY_ORG` var, `SENTRY_AUTH_TOKEN` secret (scope `project:releases`), alert rules
  (new issue + spike → email; Telegram via webhook/integration if free), UptimeRobot
  monitors (app URL + `<supabase>/functions/v1/api/health`, 5 min, alert contacts
  email + Telegram); note that the prod `/health` monitor replaces the prod keep-alive (P2.1).
- `docs/07`: document `GET /health`.

## Gates
`dart format` (after `flutter pub get`), `flutter analyze --fatal-infos`, `flutter test -j 2`
(goldens excluded locally if Windows drift), `deno test` in `supabase/functions`,
`scripts/db-test.ps1` if a migration is added.
