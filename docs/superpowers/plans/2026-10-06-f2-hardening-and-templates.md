# F-2 Hardening Migration + SQL Templates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the first Supabase migration (the "hardening" layers 1–3 from docs/16 §1), pgTAP tests that prove each layer, and the five SQL/TS templates and the review checklist in `supabase/templates/` (docs/16 §2) that every later SQL file is copied from.

**Architecture:** One migration (`<timestamp>_hardening.sql`) runs before any table or function exists. It does three things:
- creates a non-exposed `private` schema;
- installs a `ddl_command_end` event trigger that auto-enables RLS on every new `public` table;
- changes default privileges so new functions, tables and sequences are unreachable by `anon`/`authenticated` until a migration explicitly grants them.

Three pgTAP files (one per layer) prove the behaviour by creating probe objects inside a rolled-back transaction. Templates are plain files that are never executed or deployed. They encode the conventions (explicit grants, `security definer` + `search_path = ''`, `auth.uid()` first, error codes from 07 §9).

**Tech Stack:** Supabase CLI 2.117 (local Docker, Postgres 17), pgTAP (`supabase test db`), Deno Edge Functions with `npm:hono@4.13.13` and `npm:@supabase/server@1.9.1` (template only).

**Spec:**
- `docs/16-supabase-playbook.md` §1 (layers 1–3) and §2 (templates and checklist);
- `docs/06-data-model.md` (settings shape, `private` schema contents);
- `docs/07-backend-logic-and-api.md` §9 (error codes);
- `docs/15-dev-workflow.md` §1 row 2.

**Branch:** `chore/F-2-hardening` (already checked out, clean).

**Commits:** the `git commit` steps mark checkpoints. Run them through the `git-expert` agent (CLAUDE.md A8), with the attribution trailer.

## Out of scope (separate PRs, docs/15 §1)
- **Row 2b:** the schema migration from `06` and the `settings` table and seed.
- **Row 3:** installing `supabase_test_helpers`, the `is_teacher()`/`has_access()` helpers and policies, the "`private` not reachable via API" HTTP test, and the Layer-4 CI gate query (NFR-08).
- **Row 5:** wiring `supabase db lint`/advisors into CI.
- The templates *reference* these future objects. Every such reference carries a comment naming the step that creates it.

## Decisions for review (confirm before executing)
- **D1 — Close Data API exposure for tables and sequences too, not just functions.** Supabase hosted projects stop auto-granting new `public` tables and sequences to `anon`/`authenticated`/`service_role` on **2026-10-30** (changelog entry 45329). Local `config.toml` still auto-grants (`auto_expose_new_tables` unset). Without action, local and staging/prod would behave differently.
  - **Plan:** set `auto_expose_new_tables = false` in `config.toml` and put the same revokes in the hardening migration, so local, staging and prod all fail closed.
  - **Consequence:** every future table migration must contain explicit `grant` statements. The `table.sql` template carries them.
- **D2 — The docs/16 Layer-3 snippet is suspected to be insufficient.** Postgres documentation says per-schema `ALTER DEFAULT PRIVILEGES … IN SCHEMA` can only *add* to the global defaults. It cannot revoke the built-in global `EXECUTE … TO PUBLIC` on functions, so `in schema public … revoke execute … from public` may be a no-op and `anon` still inherits EXECUTE via PUBLIC.
  - **Plan:** Task 3 first runs the probe test against the docs' snippet exactly. The result decides it:
    - if the test fails, add a *global* `alter default privileges for role postgres revoke execute on functions from public;` and correct docs/16 §1;
    - if it passes, keep the global revoke anyway (harmless, explicit) and record that the docs' snippet was sufficient.
- **D3 — Add four error codes to `07` §9.** `rpc.sql`, `test.sql` and `edge-function.ts` need codes that §9 does not list yet:
  - `not_authenticated` — no JWT; already used in the docs/16 RPC example;
  - `forbidden` — student calls a teacher RPC;
  - `invalid_input` — bad arguments;
  - `internal` — unexpected failure, Edge Function only.
- **D4 — The Edge Function template uses `@supabase/server/core`** (`verifyAuth` + `createContextClient`) inside a Hono route, instead of `@supabase/server/adapters/hono`. Adapters are deprecated and removed on 2026-12-01. The core primitives are the stable path.

## Global Constraints
- **Every new SQL file starts from `supabase/templates/` and passes the review checklist (CLAUDE.md rule 10).**
- **`security definer` functions use `set search_path = ''` and fully-qualified names (`public.x`, `private.x`).**
- **Secrets and internal helpers go in `private`.** RLS policy helpers stay in `public`, because policies run as the caller (16 §1 exception).
- **RPCs get `revoke execute … from public, anon;` and then `grant execute … to authenticated;` (CLAUDE.md rule 9).**
- **No magic numbers: tunables are read from `public.settings` (rule 5).** The `settings` columns are `key text pk, value jsonb, updated_at`.
- **Error codes:** use only codes from 07 §9 (as extended by D3), raised as the exception *message* (`raise exception 'topic_locked'`), so the client maps `PostgrestException.message`.
- **Policies:** `to authenticated` plus an ownership predicate `(select auth.uid()) = user_id`. UPDATE policies need both `using` and `with check`. Never use `auth.role()` or `user_metadata`.
- **pgTAP files:** `begin; … select plan(n); … select * from finish(); rollback;` and nothing persists.
- **Nothing in `supabase/templates/` is ever applied or deployed.** It is not under `migrations/` or `functions/`.
- **No tokens, keys or PII in logs (CLAUDE.md A6).**
- **Migration files are created with `supabase migration new <name>`.** Never hand-write the timestamp.

## Review Focus
1. **Quoted or mixed-case table names** (`create table public."Probe Mixed"`): the event trigger must still enable RLS. `object_identity` arrives already quoted, so `format('%s')` is correct and `%I` would double-quote and fail. Pinned in Task 2.
2. **`CREATE TABLE AS` and `SELECT INTO` create tables too** and must get RLS. Pinned in Task 2.
3. **Functions created in `private` must not be executable by `anon`, even though `anon` lacks schema usage.** A later `grant usage` must not silently expose them. This is the global-revoke case and is pinned in Task 3.
4. **Over-revoking would break Edge Functions:** `service_role` must keep EXECUTE on new `public` functions. Pinned in Task 3.
5. **An explicit `grant execute … to authenticated` must restore access.** Otherwise the template path is broken. Pinned in Task 3.

---

## File structure

| File | Responsibility |
|------|----------------|
| `supabase/config.toml` (modify line 23, Task 3) | `auto_expose_new_tables = false` (D1) |
| `supabase/migrations/<ts>_hardening.sql` (create) | Layers 1–3 |
| `supabase/tests/00_hardening_private_schema.test.sql` | Layer 1 proof |
| `supabase/tests/01_hardening_auto_rls.test.sql` | Layer 2 proof |
| `supabase/tests/02_hardening_default_privileges.test.sql` | Layer 3 proof |
| `supabase/templates/table.sql` | Table + RLS + grants + policies + index |
| `supabase/templates/rpc.sql` | RPC shape |
| `supabase/templates/setting.sql` | New tunable |
| `supabase/templates/test.sql` | pgTAP RLS/RPC test shape |
| `supabase/templates/edge-function.ts` | Edge Function shape |
| `supabase/templates/README.md` | How to use the templates + the review checklist (English) |
| `docs/16-supabase-playbook.md` | Fix Layer-3 snippet (if D2 confirms), add the D1 table/sequence revoke, point checklist to README |
| `docs/07-backend-logic-and-api.md` §9 | Add D3 codes |

**Prerequisite (user):** start Docker Desktop. Then run `scripts/db-up.ps1` from the repo root. Every test step needs the local stack.

---

### Task 1: Layer 1 — `private` schema

**Files:**
- Create: `supabase/migrations/<ts>_hardening.sql` (via CLI)
- Create: `supabase/tests/00_hardening_private_schema.test.sql`
**Interfaces:**
- Produces: the schema `private`, with no `usage` for `public`/`anon`/`authenticated`. Tasks 2–3 and all later migrations put internal objects there.

- [ ] **Step 1: Write the failing test** `supabase/tests/00_hardening_private_schema.test.sql`

```sql
-- F-2 / NFR-08 — Layer 1 (docs/16 §1): secrets live in a schema the API roles cannot use.
begin;
create extension if not exists pgtap with schema extensions;
select plan(3);

select has_schema('private', 'private schema exists');
select ok(not has_schema_privilege('anon', 'private', 'usage'),
          'anon has no usage on schema private');
select ok(not has_schema_privilege('authenticated', 'private', 'usage'),
          'authenticated has no usage on schema private');

select * from finish();
rollback;
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `scripts/db-test.ps1`
Expected: FAIL. `has_schema('private')` is not ok, and the two privilege checks error with `schema "private" does not exist`.

- [ ] **Step 3: Create the migration and write Layer 1**

Run: `supabase migration new hardening`. This creates `supabase/migrations/<ts>_hardening.sql`. Write:

```sql
-- F-2 hardening (docs/16 §1, layers 1–3). First migration: runs before any table or function exists.
-- Layer 4 (CI gate: every public table has RLS + a policy) lands with the RLS baseline (docs/15 §1 row 3).

-- Layer 1 — private schema for secrets and internal helpers.
-- Never list it in supabase/config.toml [api] schemas, so PostgREST can never expose it.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
```

- [ ] **Step 4: Run and confirm it passes**

Run: `scripts/db-reset.ps1` then `scripts/db-test.ps1`
Expected: `00_hardening_private_schema.test.sql .. ok`, 3/3.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations supabase/tests/00_hardening_private_schema.test.sql
git commit -m "chore(F-2): add private schema"
```

---

### Task 2: Layer 2 — auto-enable RLS event trigger

**Files:**
- Modify: `supabase/migrations/<ts>_hardening.sql` (append)
- Create: `supabase/tests/01_hardening_auto_rls.test.sql`

**Interfaces:**
- Consumes: the schema `private` (Task 1).
- Produces: `private.rls_auto_enable()` (returns `event_trigger`) and the event trigger `ensure_rls`. Task 3's test asserts `private.rls_auto_enable()` is not executable by `anon`.

- [ ] **Step 1: Write the failing test** `supabase/tests/01_hardening_auto_rls.test.sql`

```sql
-- F-2 / NFR-08 — Layer 2 (docs/16 §1): every new public table gets RLS on creation (fail closed).
begin;
create extension if not exists pgtap with schema extensions;
select plan(5);

select ok(exists (select 1 from pg_event_trigger
                  where evtname = 'ensure_rls' and evtenabled <> 'D'),
          'ensure_rls event trigger exists and is enabled');

create table public.t_probe (id bigint generated always as identity primary key);
select ok((select relrowsecurity from pg_class where oid = 'public.t_probe'::regclass),
          'CREATE TABLE in public enables RLS');

create table public."Probe Mixed" (x int);
select ok((select relrowsecurity from pg_class where oid = 'public."Probe Mixed"'::regclass),
          'quoted mixed-case table name enables RLS');

create table public.t_probe_as as select 1 as x;
select ok((select relrowsecurity from pg_class where oid = 'public.t_probe_as'::regclass),
          'CREATE TABLE AS in public enables RLS');

select 1 as x into public.t_probe_into;
select ok((select relrowsecurity from pg_class where oid = 'public.t_probe_into'::regclass),
          'SELECT INTO in public enables RLS');

select * from finish();
rollback;
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `scripts/db-test.ps1`
Expected: `01_…` FAIL. Test 1 is not ok (no trigger), and tests 2–5 are not ok (`relrowsecurity = false`).

- [ ] **Step 3: Append Layer 2 to the migration**

```sql
-- Layer 2 — auto-enable RLS on every new public table. A forgotten policy then blocks access
-- instead of opening it. object_identity is already quoted, so %s (not %I) is correct.
create or replace function private.rls_auto_enable()
returns event_trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  cmd record;
begin
  for cmd in
    select * from pg_event_trigger_ddl_commands()
    where command_tag in ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      and object_type = 'table'
      and schema_name = 'public'
  loop
    execute format('alter table %s enable row level security', cmd.object_identity);
  end loop;
end;
$$;

drop event trigger if exists ensure_rls;
create event trigger ensure_rls on ddl_command_end
  when tag in ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
  execute function private.rls_auto_enable();
```

- [ ] **Step 4: Run and confirm it passes**

Run: `scripts/db-reset.ps1` then `scripts/db-test.ps1`
Expected: `00` ok 3/3, `01` ok 5/5.
**If `db reset` errors with `permission denied to create event trigger`, or tests 2–5 still fail, STOP.** That would show the `postgres` role cannot own a firing event trigger here (docs/16 §1 note: "verify in Phase 0"). Report it to the user, with no workaround: Layer 4 still covers it.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations supabase/tests/01_hardening_auto_rls.test.sql
git commit -m "chore(F-2): auto-enable RLS on new public tables"
```

---

### Task 3: Layer 3 — revoke-by-default (functions, tables, sequences)

**Files:**
- Modify: `supabase/migrations/<ts>_hardening.sql`. Insert the Layer 3 block **directly after Layer 1, before Layer 2**, so `private.rls_auto_enable()` is itself created without PUBLIC execute.
- Create: `supabase/tests/02_hardening_default_privileges.test.sql`

**Interfaces:**
- Consumes: the schema `private` (Task 1) and `private.rls_auto_enable()` (Task 2).
- Produces: the rule "nothing new in `public`/`private` is reachable by `anon`/`authenticated` without an explicit grant". The templates (Task 4) rely on it.

- [ ] **Step 1: Write the failing test** `supabase/tests/02_hardening_default_privileges.test.sql`

```sql
-- F-2 / NFR-08 — Layer 3 (docs/16 §1): nothing is callable or readable by API roles unless granted.
begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

create function public.f_probe() returns int language sql as 'select 1';
create function private.f_probe() returns int language sql as 'select 1';
create table public.t_priv_probe (id bigint generated always as identity primary key);

-- functions
select ok(not has_function_privilege('anon', 'public.f_probe()', 'execute'),
          'anon cannot execute a new public function');
select ok(not has_function_privilege('authenticated', 'public.f_probe()', 'execute'),
          'authenticated cannot execute a new public function');
select ok(not has_function_privilege('anon', 'private.f_probe()', 'execute'),
          'anon cannot execute a new private function (global PUBLIC revoke)');
select ok(not has_function_privilege('anon', 'private.rls_auto_enable()', 'execute'),
          'anon cannot execute private.rls_auto_enable');
select ok(has_function_privilege('service_role', 'public.f_probe()', 'execute'),
          'service_role keeps execute on new public functions (Edge Functions)');

-- tables and sequences (D1)
select ok(not has_table_privilege('anon', 'public.t_priv_probe', 'select'),
          'anon has no privileges on a new public table');
select ok(not has_table_privilege('authenticated', 'public.t_priv_probe', 'select,insert,update,delete'),
          'authenticated has no privileges on a new public table');
select ok(not has_sequence_privilege('authenticated', 'public.t_priv_probe_id_seq', 'usage'),
          'authenticated has no usage on a new public sequence');

-- the template path: an explicit grant restores access
grant execute on function public.f_probe() to authenticated;
select ok(has_function_privilege('authenticated', 'public.f_probe()', 'execute'),
          'explicit grant execute restores access');

-- the global PUBLIC revoke must not lock API roles out of pgTAP (RLS tests switch role, then call is()/ok())
select ok(has_function_privilege('authenticated', 'extensions.ok(boolean,text)', 'execute'),
          'pgTAP still callable by authenticated after role switch');

select * from finish();
rollback;
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `scripts/db-test.ps1`
Expected: `02_…` FAIL on tests 1–4 and 6–8. Tests 5, 9 and 10 pass. The config is still at its default here (the D1 config flip is Step 6), so the migration alone has to make these pass.

- [ ] **Step 3: Add the docs/16 snippet exactly as written (D2 check)**, after Layer 1:

```sql
alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated;
```

Run: `scripts/db-reset.ps1` then `scripts/db-test.ps1`. **Record which of tests 1–4 fail.** Expected, if D2 holds: tests 1 and 3 still fail, because `anon` inherits EXECUTE from PUBLIC's global default. Test 2 may still fail for the same reason.

- [ ] **Step 4: Replace that snippet with the full Layer 3 block** (still after Layer 1, before Layer 2):

```sql
-- Layer 3 — nothing is reachable unless a migration grants it (CLAUDE.md rule 9).
-- 3a. Functions. Postgres grants EXECUTE to PUBLIC globally; a per-schema revoke cannot undo a
--     global default, so revoke it globally (covers public and private), then drop Supabase's
--     per-schema grants to the API roles. service_role keeps its grant (Edge Functions).
alter default privileges for role postgres
  revoke execute on functions from public;
alter default privileges for role postgres in schema public
  revoke execute on functions from anon, authenticated;

-- 3b. Tables and sequences — same as Supabase's hosted default from 2026-10-30 (changelog 45329).
--     Every table migration grants exactly what its policies allow (supabase/templates/table.sql).
alter default privileges for role postgres in schema public
  revoke all on tables from anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  revoke all on sequences from anon, authenticated, service_role;
```

- [ ] **Step 5: Run and confirm everything passes**

Run: `scripts/db-reset.ps1` then `scripts/db-test.ps1`
Expected: `00` 3/3, `01` 5/5, `02` 10/10.
**If test 10 fails,** the global revoke has reached the pgTAP functions (created via `postgres`). STOP and ask the user to choose:
- **(a)** drop the global revoke and rely on the per-RPC `revoke … from public` in `rpc.sql`. Test 3 then becomes a documented known gap, guarded by the checklist.
- **(b)** keep it, and add `grant usage on schema extensions to authenticated, anon; grant execute on all functions in schema extensions to authenticated, anon;` inside each test file's transaction (put it in `test.sql`).

- [ ] **Step 6: Set local config fail-closed (D1)**, only after the migration alone is green. In `supabase/config.toml`, replace line 23 `# auto_expose_new_tables = true` with:

```toml
# Fail closed (F-2, docs/16 §1): new public objects need explicit GRANTs — matches hosted default from 2026-10-30.
# The hardening migration enforces the same on staging/prod; this keeps local identical.
auto_expose_new_tables = false
```

Run: `supabase stop`, then `scripts/db-up.ps1`, `scripts/db-reset.ps1` and `scripts/db-test.ps1`.
Expected: still 3/3, 5/5, 10/10.
- If the CLI rejects the key, revert the line and note it in the PR. The migration already covers it.
- If test 5 (`service_role` execute) now fails, the config also revokes from service_role. Stop and report.

- [ ] **Step 7: Commit**

```bash
git add supabase/migrations supabase/tests/02_hardening_default_privileges.test.sql supabase/config.toml
git commit -m "chore(F-2): revoke execute and table access by default"
```

---

### Task 4: SQL templates (`table.sql`, `rpc.sql`, `setting.sql`, `test.sql`)

**Files:**
- Create: `supabase/templates/table.sql`, `supabase/templates/rpc.sql`, `supabase/templates/setting.sql`, `supabase/templates/test.sql`

**Interfaces:**
- Consumes: Layer 3 (an explicit grant is required), Layer 2 (RLS is auto-enabled).
- Future objects, named in comments:
  - `public.profiles` and `public.settings` (row 2b);
  - `public.is_teacher()`, `public.has_access(uuid)` and the `tests.*` helpers (row 3).
- Produces: the copy-from files that every later migration and test starts from. Placeholder names are concrete and syntactically valid (`example_items`, `example_rpc`, `p_course_id`), so a copy parses before renaming.

No automated test exists for these files: they reference objects that don't exist yet. Verification is Step 5 (a manual walk through the checklist) plus the advisor review in Task 6. The first real use (row 2b/3) exercises them under `supabase test db`.

- [ ] **Step 1: Write `supabase/templates/table.sql`**

```sql
-- TEMPLATE (docs/16 §2) — copy into a migration created with `supabase migration new <name>`,
-- rename example_items, delete this header, then walk supabase/templates/README.md checklist.
-- Needs: public.profiles (docs/15 §1 row 2b), public.is_teacher() (row 3).
-- Secrets or answer data? Then this table belongs in `private`, not `public` (checklist #1).

create table public.example_items (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles (id) on delete cascade,
  -- columns …
  created_at timestamptz not null default now()
);

-- Auto-enabled by the ensure_rls event trigger; repeated so the file is correct on its own.
alter table public.example_items enable row level security;

-- Data API access: nothing is granted by default (hardening migration, Layer 3).
-- Students write through RPCs (CLAUDE.md rule 2); RLS limits direct writes to teachers.
grant select, insert, update, delete on public.example_items to authenticated;
grant select, insert, update, delete on public.example_items to service_role;
-- No anon grant unless the data is genuinely public (e.g. published catalogue).

create policy "example_items: student selects own"
  on public.example_items for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "example_items: teacher manages all"
  on public.example_items for all
  to authenticated
  using ((select public.is_teacher()))
  with check ((select public.is_teacher()));

-- Only if students may update their own rows directly — UPDATE needs USING and WITH CHECK:
-- create policy "example_items: student updates own"
--   on public.example_items for update
--   to authenticated
--   using ((select auth.uid()) = user_id)
--   with check ((select auth.uid()) = user_id);

create index example_items_user_id_idx on public.example_items (user_id);
```

- [ ] **Step 2: Write `supabase/templates/rpc.sql`**

```sql
-- TEMPLATE (docs/16 §2) — copy into a migration, rename example_rpc and its arguments,
-- delete this header, walk supabase/templates/README.md checklist.
-- Needs: public.has_access(uuid), public.is_teacher() (docs/15 §1 row 3), public.settings (row 2b).
-- Errors: raise the 07 §9 code as the message; the client maps PostgrestException.message.

create or replace function public.example_rpc(p_course_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid       uuid := auth.uid();
  v_pass_mark numeric;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  if p_course_id is null then
    raise exception 'invalid_input';
  end if;

  if not public.has_access(p_course_id) then
    raise exception 'not_enrolled';
  end if;
  -- Teacher-only RPC instead: if not public.is_teacher() then raise exception 'forbidden'; end if;

  -- Tunables come from settings, never literals (CLAUDE.md rule 5).
  select (s.value)::numeric into v_pass_mark
  from public.settings s
  where s.key = 'pass_mark';

  -- Logic: fully-qualified names only (public.x, private.x); never trust client scores or timers.

  return jsonb_build_object('ok', true, 'pass_mark', v_pass_mark);
end;
$$;

revoke execute on function public.example_rpc(uuid) from public, anon;
grant execute on function public.example_rpc(uuid) to authenticated;
```

- [ ] **Step 3: Write `supabase/templates/setting.sql`**

```sql
-- TEMPLATE (docs/16 §2) — new tunable (CLAUDE.md rule 5). Copy into a migration.
-- Needs: public.settings(key text primary key, value jsonb, updated_at) (docs/15 §1 row 2b).
-- value is jsonb: numbers '75', strings '"EGP"', objects '{"m1": 22}'.

insert into public.settings (key, value)
values ('example_key', '75'::jsonb)
on conflict (key) do nothing;  -- never overwrite a value a teacher has already changed
```

- [ ] **Step 4: Write `supabase/templates/test.sql`**

```sql
-- TEMPLATE (docs/16 §2) — pgTAP test for a table + RPC. Copy to supabase/tests/<NN>_<name>.test.sql,
-- replace example_items / example_rpc and <REQ-ID> (e.g. PRC-03, from docs/02-prd.md).
-- Needs: supabase_test_helpers (tests.* functions) and public.is_teacher() (docs/15 §1 row 3),
--        public.profiles (row 2b).
begin;
create extension if not exists pgtap with schema extensions;
select plan(5);

-- Users: two students + one teacher.
select tests.create_supabase_user('student_a');
select tests.create_supabase_user('student_b');
select tests.create_supabase_user('teacher');

insert into public.profiles (id, role, full_name) values
  (tests.get_supabase_uid('student_a'), 'student', 'Student A'),
  (tests.get_supabase_uid('student_b'), 'student', 'Student B'),
  (tests.get_supabase_uid('teacher'),   'teacher', 'Teacher')
on conflict (id) do update set role = excluded.role;

-- Seed as postgres (bypasses RLS): one row per student.
insert into public.example_items (user_id) values
  (tests.get_supabase_uid('student_a')),
  (tests.get_supabase_uid('student_b'));

-- Student A
select tests.authenticate_as('student_a');
select is((select count(*)::int from public.example_items), 1,
          '<REQ-ID>: student sees only own rows');
select is_empty($$ select 1 from public.example_items where user_id <> auth.uid() $$,
                '<REQ-ID>: student A cannot see student B rows');
select throws_ok($$ select public.example_rpc(gen_random_uuid()) $$,
                 'P0001', 'not_enrolled',
                 '<REQ-ID>: student without access gets not_enrolled');
-- Teacher-only RPC instead: throws_ok($$ select public.example_teacher_rpc() $$, 'P0001', 'forbidden', ...)

-- Teacher
select tests.authenticate_as('teacher');
select is((select count(*)::int from public.example_items), 2,
          '<REQ-ID>: teacher sees all rows');

-- Anonymous caller: no grant at all.
select tests.clear_authentication();
set local role anon;
select throws_ok($$ select 1 from public.example_items $$, '42501', null,
                 '<REQ-ID>: anon has no access to the table');
reset role;

select * from finish();
rollback;
```

- [ ] **Step 5: Check the templates against the checklist by hand.** For each of the four files, go through README checklist items 1–9 (Task 5 Step 2), then search for forbidden patterns:

Run: `grep -nE "auth\.role\(\)|user_metadata|to anon|grant .* to public" supabase/templates/*.sql`
Expected: no matches. The phrase "No anon grant" in a comment is fine, because the pattern requires `to anon`.

- [ ] **Step 6: Commit**

```bash
git add supabase/templates/table.sql supabase/templates/rpc.sql supabase/templates/setting.sql supabase/templates/test.sql
git commit -m "chore(F-2): add table, rpc, setting and test SQL templates"
```

---

### Task 5: Edge Function template, README checklist, docs updates

**Files:**
- Create: `supabase/templates/edge-function.ts`, `supabase/templates/README.md`
- Modify: `docs/07-backend-logic-and-api.md` §9 (lines 129–131), `docs/16-supabase-playbook.md` §1 Layer 3 (lines 64–72) and §2 checklist (lines 125–133)

**Interfaces:**
- Consumes: the error codes from 07 §9 plus D3; the RPC shape from Task 4.
- Produces: `ErrorCode`, a TypeScript union that mirrors 07 §9. The future `api` Edge Function copies it.

- [ ] **Step 1: Write `supabase/templates/edge-function.ts`**

```ts
// TEMPLATE (docs/16 §2) — copy to supabase/functions/<name>/index.ts, or add the route to the
// `api` function (docs/16 §8). Never deploy from supabase/templates/.
// Shape: Hono route → verify JWT → App Check (docs/16 §5, F-5) → call a Postgres RPC as the user
//        → errors as { error: { code, message } } with codes from docs/07 §9.
// Sentry (ADR-008) is wired in F-5. Business rules stay in Postgres (docs/16 §8).
import { type Context, Hono } from 'npm:hono@4.13.13';
import { createContextClient, verifyAuth } from 'npm:@supabase/server@1.9.1/core';

// Mirror of docs/07 §9 — keep in sync.
const ERROR_CODES = [
  'not_authenticated', 'forbidden', 'invalid_input', 'not_enrolled', 'access_expired',
  'topic_locked', 'attempt_closed', 'deadline_passed', 'device_limit', 'device_revoked',
  'cooldown_active', 'pool_exhausted', 'rate_limited', 'payment_invalid', 'internal',
] as const;
type ErrorCode = (typeof ERROR_CODES)[number];

function isErrorCode(value: string): value is ErrorCode {
  return (ERROR_CODES as readonly string[]).includes(value);
}

function fail(c: Context, code: ErrorCode, message: string) {
  const status = code === 'not_authenticated' ? 401
    : code === 'forbidden' ? 403
    : code === 'internal' ? 500
    : 400;
  return c.json({ error: { code, message } }, status);
}

const app = new Hono().basePath('/example-function');

app.post('/example-route', async (c) => {
  const { data: auth, error: authError } = await verifyAuth(c.req.raw, { auth: 'user' });
  if (authError) return fail(c, 'not_authenticated', 'Sign in required.');

  // App Check (docs/16 §5): monitor mode first — log a missing X-Firebase-AppCheck header,
  // enforce after a week of clean logs. Wired in F-5.

  const body = await c.req.json<{ courseId?: string }>().catch(() => null);
  if (!body?.courseId) return fail(c, 'invalid_input', 'courseId is required.');

  // Call as the user: auth.uid() and RLS apply inside the RPC.
  const supabase = createContextClient({ auth: { token: auth.token, keyName: auth.keyName } });
  const { data, error } = await supabase.rpc('example_rpc', { p_course_id: body.courseId });
  if (error) {
    if (isErrorCode(error.message)) return fail(c, error.message, error.message);
    // Log the Postgres error code only — never tokens, answer keys, payment data or PII.
    console.error('example-function/example-route rpc failed', error.code);
    return fail(c, 'internal', 'Something went wrong.');
  }
  return c.json(data);
});

export default { fetch: app.fetch };
```

- [ ] **Step 2: Write `supabase/templates/README.md`**

````markdown
# SQL / Edge Function templates

Every new SQL file starts as a copy of one of these (CLAUDE.md rule 10, docs/16 §2).
Nothing in this folder is applied or deployed — copy, rename, then delete the template header.

| Template | Use for |
|----------|---------|
| `table.sql` | New table: RLS, explicit grants, select-own + teacher-all policies, index |
| `rpc.sql` | New RPC: `security definer`, `search_path = ''`, `auth.uid()` check, 07 §9 error codes, explicit grant |
| `setting.sql` | New tunable in `settings` (`on conflict do nothing`) |
| `test.sql` | pgTAP: student A vs B, teacher, anon, RPC permission |
| `edge-function.ts` | Edge Function route: JWT → RPC as the user → `{ error: { code, message } }` |

Workflow: `supabase migration new <name>` → paste template → rename → write the test from
`test.sql` → `scripts/db-reset.ps1` → `scripts/db-test.ps1` → walk the checklist below.

## Review checklist (every SQL change)

1. New table in `public` or `private`? Anything holding answers or secrets → `private`.
2. `enable row level security` and at least one policy?
3. Policies are `to authenticated` and compare with `(select auth.uid())`? (Without it every student sees everything.) UPDATE policies have both `using` and `with check`. No `auth.role()`, no `user_metadata`.
4. `security definer` function? Then `set search_path = ''` and fully-qualified names (`public.x`).
5. Function checks `auth.uid()` on its first line?
6. `grant execute … to authenticated` only (not `anon`), after `revoke … from public, anon`?
7. Table grants match the policies (nothing is granted by default — hardening Layer 3)? No `anon` grant unless the data is public.
8. Any fixed number (pass mark, cooldown …)? It must be read from `settings`.
9. New pgTAP test, and `scripts/db-test.ps1` passes?

Also before a PR: `supabase db lint` and `supabase db advisors` show no new findings.
````

- [ ] **Step 3: Update `docs/07-backend-logic-and-api.md` §9.** Replace lines 130–131 with:

```markdown
`not_authenticated`, `forbidden`, `invalid_input`, `not_enrolled`, `access_expired`, `topic_locked`,
`attempt_closed`, `deadline_passed`, `device_limit`, `device_revoked`, `cooldown_active`, `pool_exhausted`,
`rate_limited`, `payment_invalid`, `internal` (Edge Functions only — unexpected failure).
```

- [ ] **Step 4: Update `docs/16-supabase-playbook.md`.**
  - **(a) Layer 3 (lines 64–72):** replace the code block with the Task 3 Step 4 block. Above it, add one sentence recording the D2 outcome from Task 3 Step 3. If the docs' snippet passed, the sentence states that and calls the global revoke belt-and-braces.
  - **(b) Checklist (lines 125–133):** keep the existing Arabic list. Below it, add `> Canonical English checklist (9 items, incl. table grants): supabase/templates/README.md.`

- [ ] **Step 5: Type-check the Edge Function template (best effort)**

Run: `npx -y deno@2 check supabase/templates/edge-function.ts`
Expected: no type errors. Deno is not installed locally, and `npx` downloads it. If the download fails, record "not type-checked" in the PR description. Do not install Deno globally.

- [ ] **Step 6: Commit**

```bash
git add supabase/templates/edge-function.ts supabase/templates/README.md docs/07-backend-logic-and-api.md docs/16-supabase-playbook.md
git commit -m "chore(F-2): add edge function template, review checklist and error codes"
```

---

### Task 6: Verify and ship

- [ ] **Step 1: Run a full reset and all tests.**
  - Run: `scripts/db-reset.ps1` then `scripts/db-test.ps1`.
  - Expected: 3 files, 18/18 ok.
- [ ] **Step 2: Run the linter.**
  - Run: `supabase db lint`.
  - Expected: no errors in `public` or `private`.
- [ ] **Step 3: Run the advisors.**
  - Run: `supabase db advisors --help` first to confirm the flags (CLI 2.117 ≥ 2.81.3), then run it against local.
  - Expected: no new security findings. If any appear, fix them or list them in the PR.
- [ ] **Step 4: Update the graph.** Run: `graphify update .`
- [ ] **Step 5: Review.** Use `superpowers:requesting-code-review`, then the `code-reviewer` agent (`/security-review` is recommended, because this is an RLS story). The diff has no Dart, so skip `flutter-code-quality:review-gate`.
- [ ] **Step 6: Ship.** The `git-expert` agent pushes `chore/F-2-hardening` and opens a PR titled `F-2 NFR-08: hardening migration and SQL templates`. The PR body lists D1–D4 and their outcomes.
