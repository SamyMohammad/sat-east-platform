# P3 — Revoke the blanket `authenticated` DML grant

Spec: `docs/superpowers/specs/2026-11-21-prod-readiness-design.md` (P3.4). Decision (owner, 2026-11-25): option A.

## Facts (router audit, 2026-11-25)
- `supabase/migrations/20261007003820_f2_rls_policies.sql:9` grants `select, insert, update, delete` on all `public` tables to `authenticated`; line 10 grants sequence usage. RLS is the only write gate today.
- The client never writes a table directly. Only `.from()` calls: `profiles` (select), `enrollments` (select), `mock_results` (select) — `apps/client/lib/features/auth/data/datasources/auth_remote_data_source.dart`, `features/mock/data/datasources/mock_remote_data_source.dart`. All writes go through `security definer` RPCs or Edge Functions (`service_role`).
- Every `public`-callable SQL function is `security definer`; the 21 invoker functions are all in `private` and run inside definer callers or triggers.
- Supabase default privileges grant ALL on new `public` tables to `anon`/`authenticated`.

## Task 1 — migration (from `supabase/templates/`, checklist `docs/16` §2)
New file `supabase/migrations/20261125100000_p3_revoke_dml_grants.sql`:
1. `revoke insert, update, delete, truncate, references, trigger on all tables in schema public from authenticated, anon;`
2. Revoke the column-level write grants too (table-level revoke does not remove them): `profiles` update columns (f2 line 13), `notifications (read_at)` (f2 line 16), and any other column-level `insert`/`update` grant to `authenticated`/`anon` found in `supabase/migrations/` — grep them all.
3. Sequences: `revoke usage, update on all sequences in schema public from authenticated, anon;` (keep `select` only if a test proves a reader needs it — expected: no).
4. `alter default privileges for role postgres in schema public revoke insert, update, delete, truncate, references, trigger on tables from authenticated, anon;` and the same for `usage, update on sequences`.
5. Keep every `select` grant as is (RLS gates reads). Keep the write RLS policies (defense in depth) — do not drop them.

## Task 2 — pgTAP
1. New `supabase/tests/<next number>_no_client_write_grants.test.sql` (from `supabase/templates/test.sql`), test names with `P3`:
   - zero rows in `information_schema.role_table_grants` for grantee in (`authenticated`,`anon`), schema `public`, privilege in (INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER);
   - zero rows in `information_schema.column_privileges` for the same grantees/schema with INSERT/UPDATE/REFERENCES;
   - `pg_default_acl` for role `postgres`, schema `public`, objtype tables: `authenticated` and `anon` have no a/w/d/D/x/t bits (`aclexplode`);
   - one behavioural check: as a student, `update public.profiles set phone = ...` on own row throws `42501`; as a teacher, a direct `insert into public.courses ...` throws `42501`.
2. Fix existing tests that asserted the old behaviour (e.g. `supabase/tests/08_rls_identity.test.sql:18-28` student updates own profile / `read_at`; any teacher direct-DML `lives_ok` in `09`–`11`). Flip them to `throws_ok ... '42501'` with an updated description; do not delete coverage. Test fixtures that run as `postgres` before `set role` are fine.
3. `scripts/db-reset.ps1` then `scripts/db-test.ps1` — all green. `scripts/api-private-check.ps1` still passes.

## Task 3 — docs
- `docs/06` §4 grants paragraph: authenticated/anon are read-only on `public`; all writes via RPC / Edge Function; new tables get no write grant by default.
- `docs/16` §2 checklist: add "no table write grant to `authenticated`/`anon`; writes go through an RPC".
- `docs/STATUS.md`: VID-01 manual staging check done (upload + playback, owner 2026-11-25); P3.4 done.
- Spec P3.4: mark decided (option A, 2026-11-25).

## Out of scope
Client code (no change needed), `admin_delete_student`, dropping write RLS policies, `select` grants.

## Gates
`scripts/db-reset.ps1`, `scripts/db-test.ps1`, `scripts/api-private-check.ps1`. No Flutter change → Flutter gates not needed. Do not commit.
