# AGENTS.md — SAT/EST Math Platform

Read `docs/README.md` first. Specs live in `docs/`; decisions in `docs/adr/`.

Daily workflow (per-story loop, Phase 0 order, which skill to use when): `docs/15-dev-workflow.md`.

## Stack
- Flutter (web + Android + iOS) single codebase, Clean Architecture, feature-first folders (`docs/05` §3).
- Client: Cubit/Bloc + get_it + go_router + `supabase_flutter` (no Dio); app lives in `apps/client/` — see ADR-007.
- Supabase: Postgres + RLS, Auth, Storage, Edge Functions (Deno/TypeScript), pg_cron.
- Migrations in `supabase/migrations/`; never edit prod schema by hand.

## Non-negotiable rules
1. **Answer keys never reach the client before submission.** Keys/explanations live in `private.question_keys` (non-exposed schema). Only `check_practice_answer`, `submit_attempt`, `get_attempt_review` return them.
2. Grading, unlocking, scoring, payments, enrollment, device registration → server-side (RPC / Edge Function). Never trust client-sent scores, amounts, or timers.
3. Every new table ships with RLS enabled and policies + a test in `supabase/tests/`.
4. Secrets (service role, Paymob, R2/VdoCipher, LLM, Desmos) only in Edge Function secrets.
   Secret data (answer keys, rate limits) and internal helpers live in the non-exposed `private` schema.
5. Tunable values (pass mark, cooldowns, pool split, device limit, blueprints, scale tables) come from the `settings` table — no magic numbers.
6. One shared `QuestionView` widget for practice, homework, quiz and mock.
7. Purchase UI only in the web build (`ENABLE_PURCHASE` flag) — see ADR-006.
8. UI copy is English. Content (notes, AI replies) may contain Arabic → support mixed-direction text.
9. New functions are not executable by default — every RPC gets an explicit `grant execute ... to authenticated`.
10. Every new SQL file starts from `supabase/templates/` and passes the review checklist in `docs/16` §2.

## Conventions
- Requirement IDs (e.g. `PRC-03`) from `docs/02-prd.md` in PR titles and test names.
- Error codes from `docs/07` §9.
- SPR grading rules and test table: `docs/08` §6 and `docs/12` §2 — keep tests in sync.

## Commands
Client (run from `apps/client/`; copy `env/<flavor>.example.json` to `env/<flavor>.json` first):
- `flutter run -d chrome --dart-define-from-file=env/dev.json` (web has no `--flavor`)
- `flutter run --flavor dev --dart-define-from-file=env/dev.json` (Android; flavors dev/staging/prod)
- `dart format .` · `flutter analyze --fatal-infos` · `flutter test`

Supabase (from repo root): `scripts/db-up.ps1` (`-Functions` to keep edge-runtime) · `scripts/db-reset.ps1` · `scripts/db-test.ps1` · `scripts/db-down.ps1`
