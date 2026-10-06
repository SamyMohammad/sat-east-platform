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
