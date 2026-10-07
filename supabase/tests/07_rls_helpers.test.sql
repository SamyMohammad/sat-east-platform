-- F-2 / NFR-08 — docs/06 §4 helpers: is_teacher, has_access, has_access_topic.
begin;
create extension if not exists pgtap with schema extensions;
select plan(11);

select tests.create_supabase_user('student_a');  -- active enrollment
select tests.create_supabase_user('student_b');  -- active but expired
select tests.create_supabase_user('student_c');  -- suspended
select tests.create_supabase_user('teacher');
update public.profiles set role = 'teacher' where id = tests.get_supabase_uid('teacher');

insert into public.courses (id, code, title, slug, is_published)
  values ('00000000-0000-0000-0000-0000000000c1', 'SAT', 'SAT Math', 'sat', true);
insert into public.topics (id, course_id, title, slug, is_published, is_free_preview) values
  ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1', 'Paid', 'paid', true, false),
  ('00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-0000000000c1', 'Free', 'free', true, true),
  ('00000000-0000-0000-0000-0000000000d3', '00000000-0000-0000-0000-0000000000c1', 'Draft', 'draft', false, true);
insert into public.courses (id, code, title, slug, is_published)
  values ('00000000-0000-0000-0000-0000000000c2', 'EST', 'EST Math', 'est', false);
insert into public.topics (id, course_id, title, slug, is_published, is_free_preview)
  values ('00000000-0000-0000-0000-0000000000d4', '00000000-0000-0000-0000-0000000000c2', 'Unreleased', 'unreleased', true, true);
insert into public.enrollments (user_id, course_id, status, expires_at) values
  (tests.get_supabase_uid('student_a'), '00000000-0000-0000-0000-0000000000c1', 'active',    now() + interval '30 days'),
  (tests.get_supabase_uid('student_b'), '00000000-0000-0000-0000-0000000000c1', 'active',    now() - interval '1 day'),
  (tests.get_supabase_uid('student_c'), '00000000-0000-0000-0000-0000000000c1', 'suspended', now() + interval '30 days');

select tests.authenticate_as('teacher');
select ok(public.is_teacher(), 'NFR-08: is_teacher true for the teacher');

select tests.authenticate_as('student_a');
select ok(not public.is_teacher(), 'NFR-08: is_teacher false for a student');
select ok(public.has_access('00000000-0000-0000-0000-0000000000c1'), 'NFR-08: active enrollment has access');
select ok(public.has_access_topic('00000000-0000-0000-0000-0000000000d1'), 'NFR-08: enrolled student opens a paid topic');

select tests.authenticate_as('student_b');
select ok(not public.has_access('00000000-0000-0000-0000-0000000000c1'), 'NFR-08: expired enrollment has no access');
select ok(not public.has_access_topic('00000000-0000-0000-0000-0000000000d1'), 'NFR-08: expired student cannot open a paid topic');
select ok(public.has_access_topic('00000000-0000-0000-0000-0000000000d2'), 'NFR-08: anyone signed in opens a published free preview');
select ok(not public.has_access_topic('00000000-0000-0000-0000-0000000000d3'), 'NFR-08: an unpublished free preview stays closed');
select ok(not public.has_access_topic('00000000-0000-0000-0000-0000000000d4'), 'NFR-08: a free preview in an unpublished course stays closed');

select tests.authenticate_as('student_c');
select ok(not public.has_access('00000000-0000-0000-0000-0000000000c1'), 'NFR-08: suspended enrollment has no access');

select tests.clear_authentication();
select throws_ok($$ select public.has_access('00000000-0000-0000-0000-0000000000c1') $$, '42501', null,
                 'NFR-08: anon cannot call has_access');

select * from finish();
rollback;
