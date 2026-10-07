-- F-2 / NFR-08 / PAY-01 — docs/06 §4 catalogue rows; question bank and mock forms stay closed.
begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

select tests.create_supabase_user('student_a');
select tests.create_supabase_user('teacher');
update public.profiles set role = 'teacher' where id = tests.get_supabase_uid('teacher');

insert into public.courses (id, code, title, slug, is_published) values
  ('00000000-0000-0000-0000-0000000000c1', 'SAT', 'SAT Math', 'sat', true),
  ('00000000-0000-0000-0000-0000000000c2', 'EST', 'EST Math', 'est', false);
insert into public.units (course_id, title) values
  ('00000000-0000-0000-0000-0000000000c1', 'U1'), ('00000000-0000-0000-0000-0000000000c2', 'U2');
insert into public.topics (id, course_id, title, slug, is_published) values
  ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1', 'Pub', 'pub', true),
  ('00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-0000000000c1', 'Draft', 'draft', false),
  ('00000000-0000-0000-0000-0000000000d3', '00000000-0000-0000-0000-0000000000c2', 'Hidden', 'hidden', true);
insert into public.subtopics (id, topic_id, title) values
  ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', 'S1'),
  ('00000000-0000-0000-0000-0000000000e2', '00000000-0000-0000-0000-0000000000d2', 'S2');
insert into public.prices (course_id, currency, amount_minor, kind, active) values
  ('00000000-0000-0000-0000-0000000000c1', 'EGP', 100000, 'full', true),
  ('00000000-0000-0000-0000-0000000000c1', 'EGP', 90000, 'renewal', false),
  ('00000000-0000-0000-0000-0000000000c2', 'EGP', 80000, 'full', true);
insert into public.questions (id, topic_id, subtopic_id, type, difficulty, stem_md, pool, status)
  values ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000d1',
          '00000000-0000-0000-0000-0000000000e1', 'mcq', 'E', 'x', 'practice', 'published');
insert into public.question_choices (question_id, label, body_md)
  values ('00000000-0000-0000-0000-0000000000f1', 'A', 'a');
insert into public.coupons (code, percent_off) values ('WELCOME', 10);
insert into public.mock_templates (id, course_id, name, blueprint)
  values ('00000000-0000-0000-0000-0000000000a9', '00000000-0000-0000-0000-0000000000c1', 'M', '{}');
insert into public.mock_forms (template_id, set_no, form_no, module, question_ids)
  values ('00000000-0000-0000-0000-0000000000a9', 1, 1, 'M1', '{}');

select tests.clear_authentication();
select is((select count(*)::int from public.courses), 1, 'NFR-08: anon sees only published courses');
select is((select count(*)::int from public.units), 1, 'NFR-08: anon sees units of published courses');
select is((select count(*)::int from public.topics), 1, 'NFR-08: anon sees published topics of published courses');
select is((select count(*)::int from public.subtopics), 1, 'NFR-08: anon sees subtopics of visible topics');
select is((select count(*)::int from public.prices), 1, 'NFR-08: anon sees active prices of published courses');
select throws_ok($$ select 1 from public.coupons $$, '42501', null, 'NFR-08: anon cannot read coupons');
select throws_ok($$ select 1 from public.questions $$, '42501', null, 'NFR-08: anon cannot read questions');

select tests.authenticate_as('student_a');
select is((select count(*)::int from public.courses), 1, 'NFR-08: student sees only published courses');
select is((select count(*)::int from public.questions), 0, 'NFR-08: student cannot read the question bank directly');
select is((select count(*)::int from public.question_choices), 0, 'NFR-08: student cannot read choices directly');
select is((select count(*)::int from public.coupons), 0, 'NFR-08: student cannot read coupons');
select is((select count(*)::int from public.mock_forms), 0, 'NFR-08: student cannot read mock forms');

select tests.authenticate_as('teacher');
select is((select count(*)::int from public.courses), 2, 'NFR-08: teacher sees unpublished courses');
select is((select count(*)::int from public.questions), 1, 'NFR-08: teacher reads the question bank');

select * from finish();
rollback;
