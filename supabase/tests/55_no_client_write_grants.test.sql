-- P3.4 — authenticated/anon are read-only on public tables; every write goes through an RPC / Edge Function.
begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

select tests.create_supabase_user('student_a');
select tests.create_supabase_user('teacher');
update public.profiles set role = 'teacher' where id = tests.get_supabase_uid('teacher');

-- Catalogue checks (as postgres)
select is_empty(
  $$ select table_name, privilege_type from information_schema.role_table_grants
     where table_schema = 'public' and grantee in ('authenticated', 'anon')
       and privilege_type in ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER') $$,
  'P3: no table-level write grant to authenticated/anon on public');

select is_empty(
  $$ select table_name, column_name, privilege_type from information_schema.column_privileges
     where table_schema = 'public' and grantee in ('authenticated', 'anon')
       and privilege_type in ('INSERT', 'UPDATE', 'REFERENCES') $$,
  'P3: no column-level write grant to authenticated/anon on public');

select is_empty(
  $$ select 1 from pg_catalog.pg_default_acl d
     join pg_catalog.pg_namespace n on n.oid = d.defaclnamespace
     cross join lateral aclexplode(d.defaclacl) a
     where n.nspname = 'public' and d.defaclobjtype = 'r'
       and d.defaclrole = 'postgres'::regrole
       and a.grantee in ('authenticated'::regrole, 'anon'::regrole)
       and a.privilege_type in ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER') $$,
  'P3: default privileges on new public tables give authenticated/anon no write bits');

select is_empty(
  $$ select 1 from information_schema.role_usage_grants
     where object_schema = 'public' and object_type = 'SEQUENCE'
       and grantee in ('authenticated', 'anon') and privilege_type = 'USAGE' $$,
  'P3: no sequence usage grant to authenticated/anon on public');

-- Reads stay open (RLS gates rows)
select tests.authenticate_as('student_a');
select is((select count(*)::int from public.profiles), 1, 'P3: student still reads own profile');

-- Behavioural: direct DML is refused at the privilege layer
select throws_ok($$ update public.profiles set phone = '0100' where id = auth.uid() $$, '42501', null,
                 'P3: student direct update of own profile is denied');

select tests.authenticate_as('teacher');
select throws_ok($$ insert into public.courses (code, slug, title) values ('SAT', 'p3-x', 'P3 X') $$, '42501', null,
                 'P3: teacher direct insert into courses is denied');
select ok((select count(*) from public.profiles) >= 2, 'P3: teacher still reads all profiles');

select * from finish();
rollback;
