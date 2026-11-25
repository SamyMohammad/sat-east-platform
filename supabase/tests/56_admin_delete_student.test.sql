-- P3.7 / NFR-12 / AUTH-03: teacher hard-deletes a student. From supabase/templates/test.sql.
begin;
create extension if not exists pgtap with schema extensions;
select plan(21);

select tests.create_supabase_user('del_student', 'Del.Student@Example.com');
select tests.create_supabase_user('del_other', 'del.other@example.com');
select tests.create_supabase_user('del_buyer', 'del.buyer@example.com');
select tests.create_supabase_user('del_teacher', 'del.teacher@example.com');
select tests.create_supabase_user('del_teacher2', 'del.teacher2@example.com');

insert into public.profiles (id, role, full_name, phone) values
  (tests.get_supabase_uid('del_student'),  'student', 'Delete Me', '0100000000'),
  (tests.get_supabase_uid('del_other'),    'student', 'Keep Me', null),
  (tests.get_supabase_uid('del_buyer'),    'student', 'Buyer', null),
  (tests.get_supabase_uid('del_teacher'),  'teacher', 'Teacher', null),
  (tests.get_supabase_uid('del_teacher2'), 'teacher', 'Teacher Two', null)
on conflict (id) do update set role = excluded.role, full_name = excluded.full_name, phone = excluded.phone;

insert into public.courses (id, code, title, slug, is_published) values
  ('00000000-0000-0000-0000-0000000056c1', 'SAT', 'Delete SAT', 'delete-sat', true);
insert into public.activation_codes (id, code, course_id, redeemed_by, redeemed_at) values
  ('00000000-0000-0000-0000-0000000056a1', 'DELETE-CODE-1', '00000000-0000-0000-0000-0000000056c1',
   tests.get_supabase_uid('del_student'), now());
insert into public.enrollments (user_id, course_id, activation_code_id, expires_at) values
  (tests.get_supabase_uid('del_student'), '00000000-0000-0000-0000-0000000056c1',
   '00000000-0000-0000-0000-0000000056a1', now() + interval '60 days'),
  (tests.get_supabase_uid('del_other'), '00000000-0000-0000-0000-0000000056c1', null, now() + interval '60 days');
insert into public.notifications (user_id, kind) values
  (tests.get_supabase_uid('del_student'), 'x'),
  (tests.get_supabase_uid('del_other'), 'x');
insert into public.attempts (user_id, kind, course_id) values
  (tests.get_supabase_uid('del_student'), 'practice', '00000000-0000-0000-0000-0000000056c1');
insert into public.prices (id, course_id, currency, amount_minor, kind) values
  ('00000000-0000-0000-0000-0000000056b1', '00000000-0000-0000-0000-0000000056c1', 'EGP', 1000, 'full');
insert into public.orders (user_id, course_id, price_id, amount_minor, currency, gateway) values
  (tests.get_supabase_uid('del_buyer'), '00000000-0000-0000-0000-0000000056c1',
   '00000000-0000-0000-0000-0000000056b1', 1000, 'EGP', 'paymob');

select set_config('test.del_student', tests.get_supabase_uid('del_student')::text, true);

-- Student caller
select tests.authenticate_as('del_student');
select throws_ok($$ select public.admin_delete_student('del.other@example.com') $$,
  'P0001', 'forbidden', 'P3: student cannot delete a student');

-- Anonymous caller: not executable
select tests.clear_authentication();
set local role anon;
select throws_ok($$ select public.admin_delete_student('del.other@example.com') $$,
  '42501', null, 'P3: anon cannot execute admin_delete_student');
reset role;

-- Teacher
select tests.authenticate_as('del_teacher');
select throws_ok($$ select public.admin_delete_student('   ') $$,
  'P0001', 'invalid_input', 'P3: blank email is invalid_input');
select throws_ok($$ select public.admin_delete_student(null) $$,
  'P0001', 'invalid_input', 'P3: null email is invalid_input');
select throws_ok($$ select public.admin_delete_student('nobody@example.com') $$,
  'P0001', 'student_not_found', 'P3: unknown email is student_not_found');
select throws_ok($$ select public.admin_delete_student('del.teacher2@example.com') $$,
  'P0001', 'forbidden', 'P3: another teacher cannot be deleted');
select throws_ok($$ select public.admin_delete_student('del.teacher@example.com') $$,
  'P0001', 'forbidden', 'P3: the caller cannot delete themselves');
select throws_ok($$ select public.admin_delete_student('del.buyer@example.com') $$,
  'P0001', 'student_has_orders', 'P3: a student with orders is student_has_orders');

-- Mixed case + spaces
select set_config('test.deleted', public.admin_delete_student('  DEL.student@EXAMPLE.com  ')::text, true);
select is(current_setting('test.deleted')::jsonb -> 'ok', 'true'::jsonb,
  'P3: mixed-case padded email deletes and returns ok');
select is(current_setting('test.deleted')::jsonb ->> 'deleted_user_id',
  current_setting('test.del_student')::uuid::text, 'P3: returns the deleted user id');
select ok((current_setting('test.deleted')::jsonb -> 'counts' ->> 'notifications')::int = 1
  and (current_setting('test.deleted')::jsonb -> 'counts' ->> 'attempts')::int = 1,
  'P3: returns row counts');

select tests.clear_authentication();
reset role;
reset role;
select is((select count(*)::int from auth.users where email = 'del.buyer@example.com'), 1,
  'P3: the student with orders is still there');
select is_empty($$ select 1 from auth.users where lower(email) = 'del.student@example.com' $$,
  'P3: auth user is gone');
select is_empty($$ select 1 from public.profiles where full_name = 'Delete Me' $$,
  'P3: profile is gone');
select is_empty($$ select 1 from public.attempts where user_id = current_setting('test.del_student')::uuid $$,
  'P3: attempts are gone');
select is_empty($$ select 1 from public.enrollments where user_id = current_setting('test.del_student')::uuid $$,
  'P3: enrollments are gone');
select is((select count(*)::int from public.notifications where user_id = tests.get_supabase_uid('del_other')), 1,
  'P3: other students keep their rows');
select is((select redeemed_by from public.activation_codes where id = '00000000-0000-0000-0000-0000000056a1'),
  null, 'P3: activation code redeemed_by is nulled');
select isnt((select redeemed_at from public.activation_codes where id = '00000000-0000-0000-0000-0000000056a1'),
  null, 'P3: activation code stays used');
select is((select count(*)::int from public.audit_log where action = 'student_deleted'), 1,
  'P3: exactly one audit row');
select ok((select actor = tests.get_supabase_uid('del_teacher') and entity = 'profiles'
    and entity_id = current_setting('test.del_student')::uuid
    and diff::text !~* '(del\.student|example\.com|Delete Me|0100000000)'
  from public.audit_log where action = 'student_deleted'),
  'P3: audit row names teacher and id, holds no email, name or phone');

select * from finish();
rollback;
