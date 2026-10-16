# Demo seed (P1 vertical slice)

## What it is
Demo course "SAT Math (Demo)" for the staging vertical slice: 1 unit, 3 topics, 6 skills and 72 questions (3 topics x 12 practice + 12 quiz), plus a trigger that enrols every new student in it. Files run in order: `00_structure.sql` (structure, helper `private.demo_upsert_question`, trigger), then one file per topic. `check.sql` verifies the result and is not part of the seed.

All files are idempotent; fixed UUIDs use the prefix `00000000-0000-4000-8de0-`.

## Staging and local only. Never prod.
Demo data must never go in `supabase/migrations/` and must never be applied to production. The prod deploy must not run `supabase/seeds/demo`. The demo course uses `code = 'SAT'` (codes are unique).

To retire the demo, delete the CI step "Seed staging demo data" and the seed files (or change the demo course `code`). Never edit staging data by hand: re-running the seed undoes it, and a real course with `code SAT` would break every deploy with a unique violation.

Never run `supabase db diff --linked` or `db pull` against staging into a migration: it would capture the demo function and trigger.

## How it is delivered
- Local: `scripts/db-seed-demo.ps1` (add `-Check` to also run `check.sql`; expect `demo seed OK`). It pipes each file to `psql` in the local db container.
- Staging: the CI `deploy` job step "Seed staging demo data" runs each file with `psql` on every main deploy, after "Migrate staging database".
- CI `db` job: step "Demo seed: apply twice + check" applies the seed twice and runs `check.sql`, after the pgTAP suite.
- `supabase db query --file` is not used: it rejects multi-statement files (prepared statement).

## The local/test database stays unseeded
`config.toml` `sql_paths` stays `["./seed.sql"]`. Existing pgTAP tests insert their own `SAT` course and the auto-enrol trigger would change their enrolment rows, so `supabase test db` must run on an unseeded DB.

**Footgun:** after seeding locally, `scripts/db-test.ps1` fails until the DB is unseeded again. Unseed with a rebuild: `supabase migration up --local` plus an auth container restart (`db reset` exits 139 here, see below).

## Local `supabase db reset` fails with exit 139
If `supabase db reset` fails at "Initialising schema" with `error running container: exit 139`, rebuild without it: `supabase migration up --local`, then `docker restart supabase_auth_sat-east-platform` so auth tables are created.
