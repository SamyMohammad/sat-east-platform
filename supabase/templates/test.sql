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
