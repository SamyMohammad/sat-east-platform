# F-3 row 5 — CI + staging Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. At execution start, copy this file to `docs/superpowers/plans/2026-10-07-f3-ci-staging.md` and commit it.

**Goal:** GitHub Actions runs the local checks on every PR and push. A merge to `main` deploys migrations, Edge Functions and the web build to staging. Staging never pauses.

**Architecture:** One `ci.yml` with jobs `client` and `db` running in parallel, plus `deploy` on `main` only. A separate `keep-alive.yml` runs on a daily cron. A bash `secret-grep.sh` guards every web build. Staging is `sat-staging` in a new free Supabase org. The web app goes to Cloudflare Pages (ADR-009).

**Tech Stack:** GitHub Actions, `subosito/flutter-action@v2`, `supabase/setup-cli@v1`, `cloudflare/wrangler-action@v3`, Supabase CLI 2.117.0, Flutter 3.44.1.

**Spec:** `docs/superpowers/specs/2026-10-07-f3-ci-staging-design.md` (branch `feat/F-3-ci-staging`, commit 4e279c9).

## Context
Rows 1–4 are merged. Every gate (format, analyze, `flutter test`, pgTAP, `db lint`, `api-private-check`) runs only on the developer machine today. Row 5 makes these gates run on every PR. It also gives later rows a staging environment, which the "deployed to staging" Definition of Done needs. CI is advisory because a private repo on GitHub Free has no branch protection (`docs/16` §7).

## Global Constraints
- Pin the versions: Flutter `3.44.1` stable and Supabase CLI `2.117.0`.
- The client job uses a full checkout. `apps/client/test/core/grading/spr_answer_test.dart:8-9` reads `../../supabase/tests/...`.
- No token or secret ever goes into chat or the repo. The developer runs `gh secret set` themselves. The URL and publishable key are public and go in repo **variables**.
- `supabase db lint` fails CI only at `error` level (`--fail-on error`).
- Reuse `scripts/api-private-check.ps1` as-is (`shell: pwsh`). It reads `ANON_KEY` / `SERVICE_ROLE_KEY` from `supabase status -o json`, and both keys exist in 2.117.0.
- Before writing an action's inputs, look up its current major version and inputs with context7 or the action's README. If a version above differs, use the current one.

## Spec deviation (deliberate)
- `_redirects` goes in `apps/client/web/`. `flutter build web` copies `web/` into `build/web`, so no copy step is needed.

## Review Focus
1. **The secret-grep pattern trips on library code** (e.g. a `service_role` string inside supabase/gotrue JS). Expected: a clean build passes. Pinned by Task 2, which runs the grep against a real build.
2. **A JWT carrying the service_role is base64-encoded**, so a literal grep misses it. Expected: it is caught. Pinned by a Task 1 test case with the local `SERVICE_ROLE_KEY`-shaped token.
3. **Excluding gotrue/kong breaks the stack.** pgTAP needs only db, and `api-private-check` needs kong + postgrest. Expected: both pass with the `-x` list. Pinned by the Task 3 local run.
4. **First hosted `db push` differs from local** (event trigger, `alter default privileges`, revokes). Expected: it applies clean and advisors stay at the accepted baseline. Pinned by Task 4.
5. **`deploy` runs with no functions dir content / missing variable.** Expected: the functions step is skipped, and a missing variable fails loudly before deploy. Pinned by the Task 5 guards.

---

### Task 1: `scripts/secret-grep.sh` (TDD)

**Files:**
- Create: `scripts/secret-grep.sh`, `scripts/tests/secret-grep.test.sh`

**Interfaces:**
- Produces: `scripts/secret-grep.sh <dir>`. It exits 0 when the build is clean. It exits 1 and prints `LEAK: <file>: <pattern>` for each hit.

- [ ] **Step 1: Write failing test** `scripts/tests/secret-grep.test.sh`:
```bash
#!/usr/bin/env bash
# Tests scripts/secret-grep.sh against fixture build dirs. Run: bash scripts/tests/secret-grep.test.sh
set -u
here="$(cd "$(dirname "$0")/.." && pwd)"
grep_sh="$here/secret-grep.sh"
fails=0
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

b64url() { printf '%s' "$1" | base64 | tr -d '=\n' | tr '/+' '_-'; }
jwt() { echo "$(b64url '{"alg":"HS256","typ":"JWT"}').$(b64url "$1").sig"; }

expect() { # expect <name> <exit> <content>
  local d="$tmp/$1"; mkdir -p "$d"; printf '%s' "$3" > "$d/main.dart.js"
  bash "$grep_sh" "$d" >/dev/null 2>&1; local got=$?
  if [ "$got" -eq "$2" ]; then echo "ok   $1"; else echo "FAIL $1 (exit $got, want $2)"; fails=$((fails+1)); fi
}

expect clean_publishable 0 'const k="sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH";'
expect anon_jwt          0 "const k=\"$(jwt '{"iss":"supabase","role":"anon"}')\";"
expect secret_key        1 'const k="sb_secret_N7UND0UgjKTVK-Uodkm0Hg_xSvEMPvz";'
expect service_role_word 1 'headers.role="service_role";'
expect service_role_jwt  1 "const k=\"$(jwt '{"iss":"supabase","role":"service_role"}')\";"
expect private_key       1 '-----BEGIN PRIVATE KEY-----'
expect paymob_name       1 'PAYMOB_HMAC_SECRET=abc'
expect llm_key_name      1 'ANTHROPIC_API_KEY=x'
mkdir -p "$tmp/empty"; bash "$grep_sh" "$tmp/empty" >/dev/null 2>&1 && echo "ok   empty_dir" || { echo "FAIL empty_dir"; fails=$((fails+1)); }
bash "$grep_sh" "$tmp/missing" >/dev/null 2>&1 && { echo "FAIL missing_dir (want non-zero)"; fails=$((fails+1)); } || echo "ok   missing_dir"

[ "$fails" -eq 0 ] || exit 1
```
- [ ] **Step 2:** Run `bash scripts/tests/secret-grep.test.sh`. Expected: every case FAILs because the script does not exist.
- [ ] **Step 3: Implement** `scripts/secret-grep.sh`:
```bash
#!/usr/bin/env bash
# Rule 4 / A.6: fail if a built client bundle contains server-only secrets.
# Usage: scripts/secret-grep.sh <build-dir>   (e.g. apps/client/build/web)
set -u
dir="${1:?usage: secret-grep.sh <build-dir>}"
[ -d "$dir" ] || { echo "secret-grep: no such dir: $dir" >&2; exit 2; }

patterns=(
  'sb_secret_'
  'service_role'
  '-----BEGIN'
  'PAYMOB_'
  'R2_SECRET'
  'VDOCIPHER'
  'ANTHROPIC_API_KEY'
  'OPENAI_API_KEY'
)
found=0
for p in "${patterns[@]}"; do
  while IFS= read -r f; do echo "LEAK: $f: $p"; found=1; done < <(grep -rlF -- "$p" "$dir")
done

# JWTs: decode each payload and look for a service_role claim.
while IFS=: read -r f tok; do
  payload="$(printf '%s' "$tok" | cut -d. -f2 | tr '_-' '/+')"
  while [ $(( ${#payload} % 4 )) -ne 0 ]; do payload="$payload="; done
  if printf '%s' "$payload" | base64 -d 2>/dev/null | grep -q '"role" *: *"service_role"'; then
    echo "LEAK: $f: service_role JWT"; found=1
  fi
done < <(grep -rEo 'eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*' "$dir")

[ "$found" -eq 0 ] && echo "secret-grep: clean ($dir)"
exit "$found"
```
- [ ] **Step 4:** Run `bash scripts/tests/secret-grep.test.sh`. Expected: every line `ok`, exit 0. The `service_role_jwt` case base64-encodes the word, so it proves the decode path: the literal `service_role` grep cannot see it.
- [ ] **Step 5:** Commit `feat(F-3): secret-grep for web build bundles`.

### Task 2: Real-build check + `_redirects`

**Files:**
- Create: `apps/client/web/_redirects` (content: `/* /index.html 200`)
- Maybe modify: `scripts/secret-grep.sh` (narrow a pattern only if it trips on library code)

- [ ] **Step 1:** From `apps/client`, run `flutter build web --release --dart-define-from-file=env/dev.json`.
- [ ] **Step 2:** Run `bash scripts/secret-grep.sh apps/client/build/web`. Expected: `clean`. If a pattern hits library code, inspect the hit (`grep -o '.\{60\}service_role.\{60\}'`). Narrow the pattern, add the false-positive string to the test as an `expect ... 0` case, and re-run Task 1's test.
- [ ] **Step 3:** Confirm that `build/web/_redirects` exists, i.e. that the build copied it from `web/`.
- [ ] **Step 4:** Commit `feat(F-3): Cloudflare Pages SPA redirects`.

### Task 3: `ci.yml` — jobs `client` and `db`

**Files:**
- Create: `.github/workflows/ci.yml`

**Interfaces:**
- Produces: the job ids `client` and `db`. Task 5 adds `deploy` with `needs: [client, db]`.

- [ ] **Step 1:** Check the current major versions and inputs of `actions/checkout`, `subosito/flutter-action`, `supabase/setup-cli` and `cloudflare/wrangler-action` with context7 (fallback: `gh api repos/<owner>/<repo>/releases/latest --jq .tag_name`).
- [ ] **Step 2:** Locally, run `supabase stop`, then `supabase start -x gotrue,realtime,storage-api,imgproxy,mailpit,postgres-meta,studio,edge-runtime,logflare,vector,supavisor`, then `supabase test db` and `pwsh scripts/api-private-check.ps1`. Expected: all green. If kong refuses to start without gotrue, drop `gotrue` from the list and record the reason in a YAML comment. Afterwards restore the normal stack with `scripts/db-up.ps1`.
- [ ] **Step 3: Write** `.github/workflows/ci.yml`:
```yaml
name: CI
on:
  pull_request:
  push:
    branches: [main]
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
permissions:
  contents: read

jobs:
  client:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: apps/client
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: 3.44.1
          cache: true
      - run: flutter pub get
      - run: dart format --output=none --set-exit-if-changed .
      - run: flutter analyze --fatal-infos
      - run: flutter test
      - name: Write placeholder env (PR builds never deploy)
        run: |
          cat > env/ci.json <<'EOF'
          {"FLAVOR":"staging","SUPABASE_URL":"https://example.supabase.co","SUPABASE_PUBLISHABLE_KEY":"sb_publishable_ci","ENABLE_PURCHASE":true}
          EOF
      - run: flutter build web --release --dart-define-from-file=env/ci.json
      - run: bash ../../scripts/secret-grep.sh build/web

  db:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: supabase/setup-cli@v1
        with:
          version: 2.117.0
      # Only db + kong + postgrest are needed: pgTAP + api-private-check (REST).
      - run: supabase start -x gotrue,realtime,storage-api,imgproxy,mailpit,postgres-meta,studio,edge-runtime,logflare,vector,supavisor
      - run: supabase test db
      - run: supabase db lint --fail-on error
      - run: pwsh scripts/api-private-check.ps1
```
(The `-x` list follows the outcome of Step 2. `ENABLE_PURCHASE: true` makes the PR build include the purchase code path, so the secret-grep also covers it.)
- [ ] **Step 4:** Lint the workflow with `docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:latest`. Expected: no errors.
- [ ] **Step 5:** Commit `ci(F-3): client and db checks on every PR`. Push the branch and open a **draft** PR (`F-3: CI + staging (row 5)`) so the jobs run. Run `gh pr checks --watch`. Expected: `client` and `db` both green. On a red run, use `gh run view --log-failed`, then the systematic-debugging skill.
- [ ] **Step 6 (red proof):** On a throwaway branch off this one, add an unformatted line to a Dart file, push, and confirm `client` turns red. Then delete the branch (`git push origin --delete`) and close its PR if one was created.

### Task 4: Provision staging + first manual push

The developer does the console steps. Claude runs the CLI/MCP steps and confirms before every external create.
- [ ] **Step 1 (developer):** Create a new Supabase org (free), e.g. `sat-east`.
- [ ] **Step 2:** Create project `sat-staging` in eu-central-1 in that org, via MCP `create_project` (free tier) after the developer confirms the org id and region. The developer may create it in the dashboard instead. Either way, the developer stores the DB password in their password manager.
- [ ] **Step 3 (developer, local terminal):** Run `supabase link --project-ref <ref>` (it prompts for the DB password), then `supabase db push`. Expected: 6 migrations applied with no errors. If it fails, stop and debug. Do not edit migrations in place (CLAUDE.md: never hand-edit prod schema). A fix is a new migration.
- [ ] **Step 4:** Verify via MCP: `list_migrations` returns 6 rows, `execute_sql` `select count(*) from public.settings` returns 9, and `get_advisors` (security + performance) shows only the accepted row-3 baseline. Run `curl -fsS "$URL/rest/v1/courses?select=id&limit=1" -H "apikey: <publishable>"` and expect `[]`.
- [ ] **Step 5 (developer):** Create the Cloudflare Pages project (Direct Upload), e.g. `sat-staging`. Then create an API token scoped to *Account → Cloudflare Pages → Edit*.
- [ ] **Step 6 (developer):** Set the secrets and variables (values are never pasted to Claude):
```bash
gh secret set SUPABASE_ACCESS_TOKEN
gh secret set STAGING_DB_PASSWORD
gh secret set CLOUDFLARE_API_TOKEN
gh secret set CLOUDFLARE_ACCOUNT_ID
gh variable set STAGING_PROJECT_REF --body <ref>
gh variable set STAGING_SUPABASE_URL --body https://<ref>.supabase.co
gh variable set STAGING_PUBLISHABLE_KEY --body sb_publishable_...
gh variable set CF_PAGES_PROJECT --body sat-staging
```
- [ ] **Step 7:** Claude checks the names with `gh secret list` and `gh variable list`, which show names only.

### Task 5: `deploy` job + `keep-alive.yml`

**Files:**
- Modify: `.github/workflows/ci.yml` (append job `deploy`)
- Create: `.github/workflows/keep-alive.yml`

- [ ] **Step 1: Append** to `ci.yml`:
```yaml
  deploy:
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    needs: [client, db]
    runs-on: ubuntu-latest
    concurrency:
      group: staging
      cancel-in-progress: false
    env:
      SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}
      SUPABASE_DB_PASSWORD: ${{ secrets.STAGING_DB_PASSWORD }}
      PROJECT_REF: ${{ vars.STAGING_PROJECT_REF }}
      SUPABASE_URL: ${{ vars.STAGING_SUPABASE_URL }}
      PUBLISHABLE_KEY: ${{ vars.STAGING_PUBLISHABLE_KEY }}
      PAGES_PROJECT: ${{ vars.CF_PAGES_PROJECT }}
    steps:
      - name: Check config is present
        run: |
          for v in SUPABASE_ACCESS_TOKEN SUPABASE_DB_PASSWORD PROJECT_REF SUPABASE_URL PUBLISHABLE_KEY PAGES_PROJECT; do
            [ -n "${!v}" ] || { echo "::error::$v is not set"; exit 1; }
          done
      - uses: actions/checkout@v4
      - uses: supabase/setup-cli@v1
        with:
          version: 2.117.0
      - run: supabase link --project-ref "$PROJECT_REF"
      - run: supabase db push
      - name: Deploy Edge Functions (skipped while none exist)
        run: |
          if find supabase/functions -mindepth 2 -name 'index.ts' | grep -q .; then
            supabase functions deploy --project-ref "$PROJECT_REF"
          else
            echo "No Edge Functions yet - skipped"
          fi
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: 3.44.1
          cache: true
      - name: Build web (staging)
        working-directory: apps/client
        run: |
          jq -n --arg url "$SUPABASE_URL" --arg key "$PUBLISHABLE_KEY" \
            '{FLAVOR:"staging",SUPABASE_URL:$url,SUPABASE_PUBLISHABLE_KEY:$key,ENABLE_PURCHASE:true}' > env/staging.json
          flutter pub get
          flutter build web --release --dart-define-from-file=env/staging.json
          bash ../../scripts/secret-grep.sh build/web
      - uses: cloudflare/wrangler-action@v3
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          command: pages deploy apps/client/build/web --project-name=${{ vars.CF_PAGES_PROJECT }} --branch=main
```
(`ENABLE_PURCHASE: true` is correct because this is the web build. Per ADR-006, the web build is the purchase surface.)
- [ ] **Step 2: Write** `.github/workflows/keep-alive.yml`:
```yaml
name: Keep staging awake
# docs/16 §7: free projects pause after 7 days without activity. Anon may read courses (row 3).
on:
  schedule:
    - cron: '17 6 * * *'
  workflow_dispatch:
permissions:
  contents: read
jobs:
  ping:
    runs-on: ubuntu-latest
    steps:
      - run: |
          curl -fsS "${{ vars.STAGING_SUPABASE_URL }}/rest/v1/courses?select=id&limit=1" \
            -H "apikey: ${{ vars.STAGING_PUBLISHABLE_KEY }}"
```
- [ ] **Step 3:** Run actionlint again (Task 3 Step 4). Expected: clean.
- [ ] **Step 4:** Commit `ci(F-3): deploy to staging on main, daily keep-alive`. Push, then run `gh pr checks --watch`. Expected: `client` and `db` green, and `deploy` skipped on the PR.

### Task 6: Verify, review, ship

- [ ] **Step 1:** Update `docs/15` row 5 only if a fact changed during execution (e.g. the `-x` list or the Pages project name). Commit any change as `docs(F-3): ...`.
- [ ] **Step 2:** Run `superpowers:verification-before-completion`: the Task 1 test is green, the PR checks are green, and actionlint is clean.
- [ ] **Step 3:** Review with the `code-reviewer` agent and `/security-review` (secrets handling in workflows: no `pull_request_target`, minimal `permissions`, secrets only in the `deploy` job, which runs only on `main` pushes).
- [ ] **Step 4:** Mark the PR ready (`gh pr ready`). Its body lists the developer setup steps, notes that CI is advisory, and ends with the Claude Code attribution line. The developer merges.
- [ ] **Step 5 (after merge):** Run `gh run watch` on the `main` run. Expected: `deploy` green. Then open the Pages URL: the app shell loads, and a deep link such as `/<any-route>` reloads without a 404. Run `gh workflow run keep-alive.yml`, then `gh run watch`, and expect green. Use MCP `list_migrations` on staging to confirm it matches the repo.
- [ ] **Step 6:** Run `graphify update .`. Update the `phase0-progress` memory: row 5 done, next row 6 (UI checkpoint).

## Verification (end to end)
- `bash scripts/tests/secret-grep.test.sh` → all `ok`.
- PR run: `client` and `db` green, and the throwaway red-proof branch turns `client` red.
- After merge: `deploy` is green, the Pages URL serves the app, a manual `keep-alive` returns 200, and the staging migrations equal `supabase/migrations`.
