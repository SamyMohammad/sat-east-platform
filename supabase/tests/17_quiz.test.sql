-- PRC-03: shared grader, quiz settings and practice hardening.
begin;
create extension if not exists pgtap with schema extensions;
select plan(15);

select tests.create_supabase_user('quiz_student');

insert into public.courses (id, code, title, slug, is_published, sort) values
  ('00000000-0000-0000-0000-0000000017c1', 'SAT', 'Quiz Course', 'quiz-course', true, 1);
insert into public.units (id, course_id, title, sort) values
  ('00000000-0000-0000-0000-0000000017a1', '00000000-0000-0000-0000-0000000017c1', 'U1', 1);
insert into public.topics (id, course_id, unit_id, title, slug, sort, is_published, is_free_preview) values
  ('00000000-0000-0000-0000-0000000017d1', '00000000-0000-0000-0000-0000000017c1',
   '00000000-0000-0000-0000-0000000017a1', 'T1', 'quiz-t1', 1, true, true);
insert into public.subtopics (id, topic_id, title) values
  ('00000000-0000-0000-0000-0000000017b1', '00000000-0000-0000-0000-0000000017d1', 'S1');
insert into public.questions (id, topic_id, subtopic_id, type, difficulty, stem_md, pool, status) values
  ('00000000-0000-0000-0000-0000000017e1', '00000000-0000-0000-0000-0000000017d1',
   '00000000-0000-0000-0000-0000000017b1', 'mcq', 'E', 'MCQ', 'practice', 'published'),
  ('00000000-0000-0000-0000-0000000017e2', '00000000-0000-0000-0000-0000000017d1',
   '00000000-0000-0000-0000-0000000017b1', 'spr', 'E', 'SPR', 'practice', 'published'),
  ('00000000-0000-0000-0000-0000000017e3', '00000000-0000-0000-0000-0000000017d1',
   '00000000-0000-0000-0000-0000000017b1', 'spr', 'E', 'Missing key', 'quiz', 'draft');
insert into public.question_choices (question_id, label, body_md)
  select '00000000-0000-0000-0000-0000000017e1'::uuid, label, 'Choice ' || label
  from (values ('A'), ('B'), ('C'), ('D')) choices(label);
insert into private.question_keys (question_id, correct_answer, explanation_md) values
  ('00000000-0000-0000-0000-0000000017e1', '{"choice":"B"}', 'MCQ explanation'),
  ('00000000-0000-0000-0000-0000000017e2', '{"accepted":["1/2"],"tolerance":0}', 'SPR explanation');
insert into public.enrollments (user_id, course_id, status, starts_at, expires_at) values
  (tests.get_supabase_uid('quiz_student'), '00000000-0000-0000-0000-0000000017c1',
   'active', now() - interval '1 day', now() + interval '30 days');

select is(private.grade_answer('00000000-0000-0000-0000-0000000017e1', ' b '), true,
          'PRC-03: MCQ grading ignores case and surrounding whitespace');
select is(private.grade_answer('00000000-0000-0000-0000-0000000017e1', 'A'), false,
          'PRC-03: incorrect MCQ answer is false');
select is(private.grade_answer('00000000-0000-0000-0000-0000000017e2', ' .5 '), true,
          'PRC-03: SPR accepts an equivalent form with surrounding whitespace');
select is(private.grade_answer('00000000-0000-0000-0000-0000000017e2', 'abc'), false,
          'PRC-03: malformed SPR answer is false');
select is(private.grade_answer('00000000-0000-0000-0000-0000000017e1', null), false,
          'PRC-03: null answer is false');
select is(private.grade_answer('00000000-0000-0000-0000-0000000017e2', ''), false,
          'PRC-03: empty answer is false');
select is(private.grade_answer('00000000-0000-0000-0000-0000000017e1', '   '), false,
          'PRC-03: whitespace-only answer is false');
select throws_ok($$ select private.grade_answer('00000000-0000-0000-0000-0000000017e3', '1') $$,
                 'P0001', 'invalid_key', 'PRC-03: missing key raises invalid_key');
update private.question_keys set correct_answer = '{"accepted":"1/2"}'
  where question_id = '00000000-0000-0000-0000-0000000017e2';
select throws_ok($$ select private.grade_answer('00000000-0000-0000-0000-0000000017e2', '.5') $$,
                 'P0001', 'invalid_key', 'PRC-03: malformed SPR key raises invalid_key');
update private.question_keys set correct_answer = '{"accepted":["1/2"],"tolerance":0}'
  where question_id = '00000000-0000-0000-0000-0000000017e2';

select is((select value from public.settings where key = 'quiz_size'), '12'::jsonb,
          'PRC-03: quiz_size defaults to 12');
select is((select value from public.settings where key = 'quiz_time_per_q_s'), '90'::jsonb,
          'PRC-03: quiz_time_per_q_s defaults to 90');
select is((select value from public.settings where key = 'quiz_warn_s'), '300'::jsonb,
          'PRC-03: quiz_warn_s defaults to 300');

create temp table quiz_ctx (session jsonb);
grant select, insert on quiz_ctx to authenticated;
select tests.authenticate_as('quiz_student');
select throws_ok($$ select private.grade_answer('00000000-0000-0000-0000-0000000017e1', 'B') $$,
                 '42501', null, 'PRC-03: authenticated cannot execute private.grade_answer');
insert into quiz_ctx select public.get_practice_questions('00000000-0000-0000-0000-0000000017d1');

select tests.clear_authentication();
reset role;
update public.questions set pool = 'quiz' where id = '00000000-0000-0000-0000-0000000017e1';
update public.questions set status = 'draft' where id = '00000000-0000-0000-0000-0000000017e2';
select tests.authenticate_as('quiz_student');
select throws_ok($$ select public.check_practice_answer(
  (select (session ->> 'attempt_id')::uuid from quiz_ctx), '00000000-0000-0000-0000-0000000017e1', 'B', 1) $$,
  'P0001', 'invalid_input', 'PRC-03: question moved to quiz pool after draw raises invalid_input');
select throws_ok($$ select public.check_practice_answer(
  (select (session ->> 'attempt_id')::uuid from quiz_ctx), '00000000-0000-0000-0000-0000000017e2', '.5', 1) $$,
  'P0001', 'invalid_input', 'PRC-03: question unpublished after draw raises invalid_input');

select * from finish();
rollback;
