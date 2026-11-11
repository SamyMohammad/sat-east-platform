# R1c — Load test on staging (k6, 300 concurrent students)

## Context

Roadmap R1 (docs/STATUS.md). NFRs say: question load p95 < 500 ms (NFR-01), submit p95 < 1.5 s (NFR-02), at 300 concurrent students (docs/05 §7). Nothing has ever measured this. R1a added the indexes; R1c measures.

R1b (rate-limit rollback) is closed without code: Postgres has no autonomous transactions, so the only fixes are a `dblink` loopback (needs a DB password inside the DB) or rewriting ~18 RPCs to return errors instead of raising. The one guess-style RPC (`redeem_activation_code`) already returns errors. Flood protection belongs at the edge. Recorded in STATUS, not fixed.

User decision (2026-11-11): mint JWTs from a staging JWT secret stored as a GitHub secret, because Supabase Auth limits password sign-ins to ~30 per 5 min per IP.

Outcome: a manual GitHub workflow that seeds N load students on staging, runs a realistic student flow with k6, reports p95s and the top SQL statements, and always deletes the load students.

## Owner action (before the first run)

1. Supabase dashboard, staging project `sat-staging` → Settings → JWT Keys. If the **legacy JWT secret** (HS256) is still accepted, copy it. If the project uses only new asymmetric signing keys, stop and tell me — the plan then switches to the "raise sign-in limit temporarily" option.
2. GitHub → Settings → Environments → the environment CI's staging deploy uses (or repo secrets) → add `STAGING_JWT_SECRET`.

## Changes (all new files unless noted)

### 1. `scripts/load/seed_users.sql` — create load students
- psql variable `:n` (count). Insert `n` rows into `auth.users` with fixed-pattern ids `00000000-0000-4000-8a0d-<12-digit n>` and emails `load-<n>@load.test`, mirroring `supabase/seeds/demo/ci_fixture.sql` (columns, `on conflict (id) do nothing`).
- Confirm (read migrations) that a trigger creates `public.profiles` with role `student`; if not, insert profiles too. The demo seed's `private.demo_enroll_new_student` trigger (`supabase/seeds/demo/00_structure.sql:240-262`) enrols each new profile in the demo course; verify enrolment exists after insert and insert explicitly if not.
- Output nothing secret.

### 2. `scripts/load/cleanup_users.sql`
- `delete from auth.users where email like 'load-%@load.test';` — cascades to profiles, enrolments, attempts, progress, exposure (all `on delete cascade` from profiles per `20261006235113_f2_schema.sql`). Also delete their `private.rate_limits` rows (key contains the uid).
- Must be safe to run when no load users exist.

### 3. `scripts/load/mint_tokens.mjs` — Node, no dependencies
- Reads `STAGING_JWT_SECRET`, `LOAD_USERS` (n); writes `tokens.json` (array of HS256 JWTs: `sub`=user id, `role`/`aud`=`authenticated`, `iat`, `exp`=now+2h, `email`).
- Never prints tokens. Unit-testable pure function `mintToken(secret, sub, nowSec)` exported; test with `node --test scripts/load/mint_tokens.test.mjs` against a fixed vector (decode header/payload, verify HMAC with `node:crypto`).

### 4. `load/k6/student_flow.js` — k6 script
- `open('tokens.json')`; VU *i* uses token `i % n`. Headers: `apikey` = publishable key, `Authorization: Bearer <token>`. Calls PostgREST RPC endpoints `POST {SUPABASE_URL}/rest/v1/rpc/<name>`.
- Iteration (one student session), each request tagged `name:<rpc>`:
  1. `get_course_map` → `get_topic(p_topic_id = demo topic 1)`.
  2. `get_practice_questions(topic 1)` → for each returned question `check_practice_answer(attempt, question, '<first choice or "1">', time_ms)` with `sleep(3–8 s)` between answers (respects `rate_answer_per_min` 30).
  3. If `get_topic` now shows the quiz startable: `start_quiz` → `save_answer` per question (read the 7-arg signature in migrations) with think time → `submit_attempt`. If quiz is locked/cooling down, skip without counting as error.
- Treat expected business errors (`rate_limited`, `pool_exhausted`, quiz cooldown) as tagged non-failures; anything 5xx or unexpected 4xx counts as failure.
- Options: stages ramp 0→`VUS` over 2 min, hold `DURATION` (default 5 m), ramp down 1 min. Thresholds: `http_req_duration{name:get_practice_questions}` p(95)<500, `{name:get_topic}` p(95)<500, `{name:check_practice_answer}` p(95)<500, `{name:submit_attempt}` p(95)<1500, `http_req_failed` rate<0.01. `handleSummary` writes `summary.json` + a markdown table.
- Demo topic ids/answer formats: read `supabase/seeds/demo/00_structure.sql` and `10_topic1_linear_equations.sql`.

### 5. `.github/workflows/load-staging.yml` — `workflow_dispatch` only
- Inputs: `vus` (default 300), `duration` (default `5m`). Concurrency group `load-staging`.
- Reuses CI's staging values (copy `PROJECT_REF`, `SUPABASE_URL`, `PUBLISHABLE_KEY` env + secrets `SUPABASE_ACCESS_TOKEN`, `STAGING_DB_PASSWORD` exactly as `.github/workflows/ci.yml` does; same `supabase/setup-cli` version 2.117.0; `supabase link` → pooler URL from `supabase/.temp/pooler-url`, like the "Seed staging demo data" step).
- Guard: fail if `PROJECT_REF` equals `vars.PROD_PROJECT_REF`.
- Steps: link → `pg_stat_statements_reset()` → seed users (n = vus) → `node scripts/load/mint_tokens.mjs` → `grafana/setup-k6-action` (pinned version) → `k6 run` → query top 15 statements by `total_exec_time` and `mean_exec_time` from `extensions.pg_stat_statements` into the job summary → upload `summary.json` artifact → cleanup (`if: always()`).
- Never echo tokens or secrets; `tokens.json` is deleted in the cleanup step and never uploaded.

### 6. Docs
- `docs/setup/load-test.md`: what it does, the owner secret, how to run (Actions → Load staging → Run), how to read results, warning that staging is unusable during the run.
- `docs/STATUS.md` (router, after merge): R1b closed as by-design with the reason above; R1c row with the first run's numbers.

## Execution
- Branch `perf/r1c-load-test` off `main` in worktree `../sat-r1c`.
- `implementer` agent (claude-sonnet-5-5) builds tasks 1–6 (tests first for task 3); does not commit.
- Router review: diff + `node --test scripts/load/`, `k6 inspect load/k6/student_flow.js` if k6 is available in CI (add a cheap CI-free check: run `node --check` on the .mjs files), workflow YAML lint via `actionlint` if installed, otherwise careful read. Commit, push, PR.

## Verification
1. PR CI stays green (no app code touched).
2. After merge and the owner secret: run the workflow with `vus=10, duration=1m` first (smoke) → confirm users seeded, requests 2xx, summary present, cleanup removed all `load-%` users (check via Supabase MCP `execute_sql` on staging).
3. Then `vus=300, duration=5m`. Record p95 per RPC and the top statements in STATUS. Any threshold breach becomes its own story (likely `finish_quiz` / `apply_mastery` loop).
