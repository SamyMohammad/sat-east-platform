# Prod P1 — CI speed + repo guardrails

Spec: [prod readiness](../specs/2026-11-21-prod-readiness-design.md) §P1 (the spec lands with P0; this plan is self-contained).

Baseline (2026-11-21): PR CI runs take 6–8 min and main runs 8–10 min. Critical path is the `client` job at 5m52 (`flutter test` 3m55, `build web` 1m03). `db` takes 1m26, `functions` 13s. Target: a PR finishes in ≤ 4 min, with the same checks.

## Task 1 — restructure `.github/workflows/ci.yml`
- **`changes` job** (PRs only) with `dorny/paths-filter@v3`. It outputs:
  - `client`: `apps/client/**`, `supabase/tests/**` (`spr_answer_test.dart` reads it), `scripts/secret-grep.sh`, `scripts/tests/**`, `.github/workflows/ci.yml`
  - `db`: `supabase/**`, `scripts/api-private-check.ps1`, `ci.yml`
  - `functions`: `supabase/functions/**`, `supabase/templates/**`, `tools/**`, `ci.yml`
- Each job runs `if: github.event_name != 'pull_request' || needs.changes.outputs.<x> == 'true'`. On a push to `main` every job runs (staging `deploy` needs them all). `changes` itself must skip on push without blocking the other jobs: use `if: github.event_name == 'pull_request'` on `changes`, and `always() && (...)` guards on dependants so a skipped `changes` doesn't skip them. Check the expression semantics.
- **Split `client`:**
  - `client-test`: a matrix of 3 shards. Each shard runs `pub get`, then `flutter test --exclude-tags golden --total-shards 3 --shard-index ${{ matrix.shard }}`. Only shard 0 also runs `dart format --set-exit-if-changed` and `flutter analyze --fatal-infos`.
  - `client-build`: placeholder env, `flutter build web --release`, `secret-grep.test.sh`, `secret-grep.sh build/web`. Also fail if any file in `build/web` is over 25 MiB (Cloudflare Pages per-file limit): `find build/web -type f -size +25M | grep . && exit 1 || true`, written so it fails correctly.
- **`ci-ok` aggregator:** `needs: [changes, client-test, client-build, db, functions]`, `if: always()`. It fails when any needed result is `failure` or `cancelled` (skipped is OK). This becomes the only required check.
- `deploy`: `needs: [client-test, client-build, db, functions]`, otherwise unchanged. Rename the stale step "Deploy Edge Functions (skipped while none exist)" to "Deploy Edge Functions".
- Add `timeout-minutes` to every job: changes 5, client-test 15, client-build 15, db 15, functions 10, ci-ok 5, deploy 30. Also `keep-alive.yml` 5.
- Header comment at line 2: drop "Advisory: the repo has no branch protection". Say that `ci-ok` is the required check.

## Task 2 — guardrail files
- `.github/dependabot.yml`: ecosystems `github-actions` (/), `pub` (/apps/client), `npm` (/apps/landing) if `apps/landing/package.json` exists (check). Weekly, one grouped PR per ecosystem, `open-pull-requests-limit: 3`. Leave Flutter SDK pins alone.
- `.github/CODEOWNERS`: `* @SamyMohammad`.
- `SECURITY.md` at the repo root: how to report privately (GitHub private vulnerability reporting), scope, no bounty. English, short.

## Task 3 — secret-grep patterns
- `scripts/secret-grep.sh`: add key-body patterns (prefix plus enough characters to avoid false hits in Flutter/JS libs):
  - Groq `gsk_[A-Za-z0-9]{20,}`
  - Brevo `xkeysib-[a-f0-9]{20,}` and `xsmtpsib-[a-f0-9]{20,}`
  - Sentry auth token `sntrys_[A-Za-z0-9_=-]{20,}` (not the DSN, which is public)
  - Cloudflare API token variable names `CLOUDFLARE_API_TOKEN`
  - `R2_ACCESS_KEY_ID`
  - Turnstile `TURNSTILE_SECRET`
- `scripts/tests/secret-grep.test.sh`: one positive case per new pattern and one negative case (a public Sentry DSN stays clean). Run it locally with Git Bash.
- Then build web locally (or use the CI build from Task 1) and make sure the real bundle stays `clean`.

## Task 4 — weekly ops check workflow
`.github/workflows/ops-weekly.yml`: schedule weekly plus `workflow_dispatch`, `timeout-minutes: 5`, `permissions: contents: read`. Step 1: read repo variable `SUPABASE_TOKEN_EXPIRES` (ISO date), and fail with `::error::` when it is missing or under 21 days away. A failed run emails the owner. Add a comment saying P2 adds the Free-limit checks to this same file. Document the variable in `docs/16` §7 next to the expiry note.

## Task 5 — doc drift
- `docs/16` §7: the repo is **public**, so branch protection is available and on: required check `ci-ok`, no force-push.
- `docs/12` §4: merges are blocked on a red `ci-ok`.
- `docs/15` only if it mentions an advisory CI.

## Out of scope
Prod workflow apt caching (rare runs, saves little; revisit if it gets slow), branch protection itself (the router applies it with `gh api` after the CI PR merges and proves green), and all P2+ items.

## Gates
- `actionlint` if installed (otherwise `npx -y @action-validator/cli` or skip with a note).
- `bash scripts/tests/secret-grep.test.sh`.
- Prove it: open a draft PR, check the timings, then push a docs-only commit and confirm the Flutter jobs skip and `ci-ok` is green.

## Router after merge
`gh api -X PUT repos/SamyMohammad/<repo>/branches/main/protection` with required check `ci-ok` and strict=false, force-push and deletion off, no review requirement (solo dev). Then test that a red PR is blocked. Set repo variable `SUPABASE_TOKEN_EXPIRES=2027-01-05`.
