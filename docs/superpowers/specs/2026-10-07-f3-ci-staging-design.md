# F-3 row 5 — CI + staging (design)

Story: docs/15 §1 row 5 (F-3). Sources: `docs/16` §7, `docs/05` §6, ADR-009.

## Goal
Every PR and every push runs the same checks the developer runs locally. Every merge to `main`
puts the schema, the Edge Functions and the web app on staging. The free staging project does not
pause.

## Scope
**In:** `.github/workflows/ci.yml` (jobs `client`, `db`, `deploy`), `.github/workflows/keep-alive.yml`,
a secret-grep script, `_redirects` for the web build, staging project `sat-staging`, the first
manual `db push`.

**Out:** prod environment (week 11), path filters, Android/iOS builds in CI, Sentry release
upload (row 10), custom domain (Q-01).

## Decisions (agreed 2026-10-07)
1. Staging = new free Supabase project `sat-staging` in eu-central-1, in a **new Supabase org**.
   The existing org is on the free plan and already has two active projects.
2. Web hosting = Cloudflare Pages (ADR-009).
3. CI is advisory. Branch protection is unavailable on a private repo on GitHub Free. The rule
   is written in `docs/16` §7: never merge a PR with red or missing checks.
4. One workflow file holds the checks and the deploy. The deploy job needs both check jobs to pass.
5. No path filters yet. Both check jobs run in parallel, at roughly 8–10 min per run against the
   2000 free minutes a month. Path filters get added if minutes run short.

## `ci.yml`
Triggers: `pull_request`, `push` to `main`. `concurrency: ci-${{ github.ref }}`, cancel in progress.

**Job `client`** (ubuntu, full checkout, because the SPR test reads `../../supabase/tests/fixtures`):
1. `subosito/flutter-action` pinned to Flutter `3.44.1` stable, with cache.
2. From `apps/client`: `flutter pub get`, `dart format --output=none --set-exit-if-changed .`,
   `flutter analyze --fatal-infos`, `flutter test`.
3. `flutter build web --release --dart-define-from-file=env/ci.json`. CI writes `env/ci.json`
   with placeholder values, because PR builds never deploy.
4. `scripts/secret-grep.sh apps/client/build/web`.

**Job `db`** (ubuntu):
1. `supabase/setup-cli` pinned to `2.117.0`.
2. `supabase start -x` excluding studio, storage-api, realtime, imgproxy, edge-runtime, logflare,
   vector, mailpit, supavisor and postgres-meta. db, kong, rest and gotrue stay up. Whether
   gotrue can be dropped as well is checked during implementation.
3. `supabase test db`, `supabase db lint --fail-on error`.
4. `pwsh scripts/api-private-check.ps1`.

**Job `deploy`** (`if: push to main`, `needs: [client, db]`, `concurrency: staging`, no cancel):
1. `supabase link --project-ref $STAGING_PROJECT_REF` with `SUPABASE_ACCESS_TOKEN` and
   `SUPABASE_DB_PASSWORD`.
2. `supabase db push`. The settings seed is a migration, so it ships with the push.
3. `supabase functions deploy`, guarded so it is skipped while `supabase/functions` holds no function.
4. Write `env/staging.json` from repo variables (`STAGING_SUPABASE_URL`,
   `STAGING_PUBLISHABLE_KEY`; both public), then build web, then secret-grep.
5. Copy `_redirects` (`/* /index.html 200`) into `build/web`, then
   `wrangler pages deploy build/web --project-name=<pages project> --branch=main`.

## `keep-alive.yml`
`schedule` daily, plus `workflow_dispatch`. It runs
`curl -fsS "$STAGING_SUPABASE_URL/rest/v1/courses?select=id&limit=1"` with the publishable key.
Anon may read `courses` (row 3), so the request reaches Postgres and gets a 200 even when the table
is empty. Scheduled runs work only from the default branch, so this is verified with a manual
dispatch after merge.

## Secret-grep (`scripts/secret-grep.sh <dir>`)
The script fails if any file in the build contains any of these:
- `sb_secret_`
- `service_role`
- `-----BEGIN`
- a JWT whose payload decodes to `"role":"service_role"`
- the names `PAYMOB_`, `R2_SECRET`, `VDOCIPHER`, `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`

`sb_publishable_` and the anon JWT are allowed. Before it is wired in, the script runs against a
real local build to confirm it gives no false positives from `supabase_flutter` and
`gotrue` strings. Any pattern that trips on library code gets narrowed.

## GitHub config (the developer sets it; tokens never go into chat)
- Secrets: `SUPABASE_ACCESS_TOKEN`, `STAGING_DB_PASSWORD`, `CLOUDFLARE_API_TOKEN` (Pages edit only),
  `CLOUDFLARE_ACCOUNT_ID`.
- Variables: `STAGING_PROJECT_REF`, `STAGING_SUPABASE_URL`, `STAGING_PUBLISHABLE_KEY`,
  `CF_PAGES_PROJECT`.

## Rollout order
1. Create the new org and `sat-staging`, then create the Cloudflare Pages project.
2. Run the first `supabase link` + `db push` from the developer machine, before merge. If the
   hardening migration (event trigger, default privileges) behaves differently on a hosted project,
   it shows up here. Then run `get_advisors` on staging.
3. Set the secrets and variables. Open the PR. The `client` and `db` jobs must be green.
4. Merge, watch the `deploy` job, open the Pages URL, then dispatch `keep-alive` once.

## Done when
- A PR run shows `client` and `db` green, and a deliberate format error turns `client` red.
- After merge, staging's migrations list matches `supabase/migrations`, the Pages URL loads the app
  shell, and a manual `keep-alive` run returns 200.
