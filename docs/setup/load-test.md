# Setup: staging load test (R1c)

Measures the NFRs in `docs/05` §7 on the staging Supabase project: question load p95 < 500 ms
(NFR-01) and submit p95 < 1.5 s (NFR-02) with 300 concurrent students.

## What it does
The manual workflow `.github/workflows/load-staging.yml` ("Load staging"):
1. Refuses to run if `STAGING_PROJECT_REF` equals `PROD_PROJECT_REF`.
2. Links the staging project, resets `pg_stat_statements`, and creates N load students
   (`scripts/load/seed_users.sql`, emails `load-<n>@load.test`). The existing triggers give each
   one a profile and a demo-course enrolment.
3. Mints one HS256 JWT per student from the staging JWT secret (`scripts/load/mint_tokens.mjs`).
   This avoids Supabase Auth's sign-in limit (about 30 per 5 min per IP). The tokens live only in
   `tokens.json` on the runner: never printed, never uploaded, deleted in the cleanup step.
4. Runs k6 (`load/k6/student_flow.js`): ramp up 2 min, hold `duration`, ramp down 1 min. Each
   virtual student does: course map, topic, practice set with 3-8 s think time, homework when the
   server asks for it, then the quiz when it is available, and submit.
5. Writes the per-RPC p95 table and the top 15 SQL statements (by total and by mean time) to the
   job summary, and uploads `summary.json` / `summary.md` as the `k6-summary` artifact.
6. Always (even on failure or cancel): deletes `tokens.json`, the load users and their rate-limit
   rows (`scripts/load/cleanup_users.sql`).

## One-time setup (owner)
1. Supabase dashboard, staging project, Settings, JWT Keys. If the **legacy JWT secret** (HS256)
   is still accepted, copy it. If the project uses only asymmetric signing keys, this approach
   does not work: tell the team, and the plan switches to raising the sign-in limit temporarily.
2. GitHub, Settings, Secrets and variables, Actions: add the secret `STAGING_JWT_SECRET`.
3. Already used by CI and reused here: variables `STAGING_PROJECT_REF`, `STAGING_SUPABASE_URL`,
   `STAGING_PUBLISHABLE_KEY`, `PROD_PROJECT_REF`; secrets `SUPABASE_ACCESS_TOKEN`,
   `STAGING_DB_PASSWORD`.
4. The demo seed (`supabase/seeds/demo/`) must already be on staging: the flow uses demo topic 1.

## How to run
Actions, "Load staging", Run workflow. Inputs: `vus` (default 300, also the number of load users)
and `duration` (default `5m`).

Run a smoke first (`vus=10`, `duration=1m`): check the job summary has numbers, then confirm no
load users remain (`select count(*) from auth.users where email like 'load-%@load.test'` is 0).
Then run `vus=300`, `duration=5m`.

**Staging is unusable for other work during the run**, and the run resets `pg_stat_statements`.
Do not run it while a deploy or demo is in progress (concurrency group `load-staging` only stops
two load runs from overlapping).

## How to read the results
- The k6 step fails if a threshold is breached: p95 of `get_practice_questions`, `get_topic`,
  `check_practice_answer` over 500 ms; `submit_attempt` (quiz) over 1500 ms; `http_req_failed` or
  the unexpected-RPC-error rate over 1%. The summary still prints and cleanup still runs.
- Per-RPC table: requests, avg, p(95), max in ms. `submit_homework` is the homework submit,
  tracked apart from the quiz `submit_attempt`.
- "Business errors" are expected product rejections (`rate_limited`, `pool_exhausted`,
  `cooldown_active`, `review_needed`, `homework_needed`, `practice_needed`, `attempt_closed`,
  `deadline_passed`). They are counted, not failures. A high `rate_limited` count means the load
  profile is harsher than a real student; it is not a server fault.
- Anything else (5xx, 401, an unknown 400 message) counts as a failure.
- Top statements: if a threshold is breached, the worst `total_exec_time` and `mean_exec_time`
  rows point at the RPC to fix. Each breach becomes its own story.

## Known limits
- Students answer with the first choice, so most quiz attempts fail and later iterations hit the
  quiz cooldown or review gate. The quiz is skipped then; only early iterations measure quiz
  submit. A long hold therefore gives fewer `submit_attempt` samples than `check_practice_answer`.
- Pooler connections count against the staging project's limits; a real prod run needs its own
  project and plan.
