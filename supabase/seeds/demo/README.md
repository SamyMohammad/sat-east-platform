# Demo seed (P1 vertical slice)

## What it is
Demo course "SAT Math (Demo)" for the staging vertical slice: 1 unit, 3 topics, 10 skills and 157 questions (3 topics x 12 practice + 12 quiz = 72, plus 85 `mock_reserve` mock questions), plus a trigger that enrols every new student in it. Files run in order: `00_structure.sql` (structure, helper `private.demo_upsert_question`, trigger), one file per topic, then `40_mock_reserve.sql`. `check.sql` verifies the result and is not part of the seed.

`40_mock_reserve.sql` (MCK-03) stocks one SAT mock form plus one spare per cell: 85 questions with `source = 'demo-mock'` and `external_ref` `DEMO-MOCK-<ALG|ADV|PSD|GEO>-<n>`, four skills `DEMO.MOCK.*` with the exact blueprint domain strings. The cells are generated from `private.mock_module_slots` over the `mock_blueprint_sat` setting, so it needs the MCK-03 migration. `check.sql` asserts `private.mock_shortage(private.mock_template_for(demo course)) = '[]'` (which creates the SAT template row, as intended).

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
