-- F-2 hardening (docs/16 §1, layers 1–3). First migration: runs before any table or function exists.
-- Layer 4 (CI gate: every public table has RLS + a policy) lands with the RLS baseline (docs/15 §1 row 3).

-- Layer 1 — private schema for secrets and internal helpers.
-- Never list it in supabase/config.toml [api] schemas, so PostgREST can never expose it.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

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
