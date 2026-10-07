-- F-2 / NFR-08 — Layer 4 (docs/16 §1): every public table has RLS and a policy; nothing in private
-- is granted to API roles. Every story that adds a table must keep this green.
begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

select is_empty($$
  select c.relname from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind in ('r','p')
    and (not c.relrowsecurity
         or not exists (select 1 from pg_policies p
                        where p.schemaname = 'public' and p.tablename = c.relname))
$$, 'NFR-08: every public table has RLS enabled and at least one policy');

select is_empty($$
  select c.relname from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind in ('v','m')
$$, 'NFR-08: no views or materialized views in public (they bypass RLS)');

select is_empty($$
  select c.relname from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'private' and c.relkind = 'r'
    and (has_table_privilege('anon', c.oid, 'select,insert,update,delete')
      or has_table_privilege('authenticated', c.oid, 'select,insert,update,delete'))
$$, 'NFR-08: anon and authenticated have no privileges on private tables');

select ok(has_table_privilege('service_role', 'public.profiles', 'select,insert,update,delete'),
          'NFR-08: service_role can use public tables (Edge Functions)');

select * from finish();
rollback;
