-- F-2 / NFR-08 — row 2b ships locked: RLS on, no API-role grants until the RLS baseline (row 3).
-- Row 3 replaces the "no table privileges yet" check when grants and policies land.
begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

select is((select count(*)::int from pg_class c join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity),
          0, 'every public table has RLS enabled');

select is((select count(*)::int from pg_class c join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'private' and c.relkind = 'r' and not c.relrowsecurity),
          0, 'every private table has RLS enabled');

select is((select count(*)::int from pg_class c join pg_namespace n on n.oid = c.relnamespace
           where n.nspname in ('public','private') and c.relkind = 'r'
             and (has_table_privilege('anon', c.oid, 'select,insert,update,delete')
               or has_table_privilege('authenticated', c.oid, 'select,insert,update,delete'))),
          0, 'anon and authenticated have no table privileges yet');

select ok(has_table_privilege('service_role', 'public.profiles', 'select,insert,update,delete'),
          'service_role can use public tables (Edge Functions)');

select * from finish();
rollback;
