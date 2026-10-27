-- SEC / PRC-01 / PRC-03: rate limits and practice topic validation. From templates/test.sql.
begin;
create extension if not exists pgtap with schema extensions;
select plan(25);

select tests.create_supabase_user('rate_a');
select tests.create_supabase_user('rate_b');

insert into public.courses (id, code, title, slug, is_published, sort) values
  ('00000000-0000-0000-0000-0000000019c1', 'SAT', 'Rate Course', 'rate-course', true, 1);
insert into public.units (id, course_id, title, sort) values
  ('00000000-0000-0000-0000-0000000019a1', '00000000-0000-0000-0000-0000000019c1', 'U1', 1);
insert into public.topics (id, course_id, unit_id, title, slug, sort, is_published, is_free_preview) values
  ('00000000-0000-0000-0000-0000000019d1', '00000000-0000-0000-0000-0000000019c1',
   '00000000-0000-0000-0000-0000000019a1', 'T1', 'rate-t1', 1, true, true),
  ('00000000-0000-0000-0000-0000000019d2', '00000000-0000-0000-0000-0000000019c1',
   '00000000-0000-0000-0000-0000000019a1', 'T2', 'rate-t2', 2, true, true);
insert into public.subtopics (id, topic_id, title) values
  ('00000000-0000-0000-0000-0000000019b1', '00000000-0000-0000-0000-0000000019d1', 'S1'),
  ('00000000-0000-0000-0000-0000000019b2', '00000000-0000-0000-0000-0000000019d2', 'S2');
insert into public.questions (id, topic_id, subtopic_id, type, difficulty, stem_md, pool, status) values
  ('00000000-0000-0000-0000-0000000019e1', '00000000-0000-0000-0000-0000000019d1',
   '00000000-0000-0000-0000-0000000019b1', 'mcq', 'E', 'Practice 1', 'practice', 'published'),
  ('00000000-0000-0000-0000-0000000019e2', '00000000-0000-0000-0000-0000000019d1',
   '00000000-0000-0000-0000-0000000019b1', 'mcq', 'E', 'Practice 2', 'practice', 'published'),
  ('00000000-0000-0000-0000-0000000019e3', '00000000-0000-0000-0000-0000000019d2',
   '00000000-0000-0000-0000-0000000019b2', 'mcq', 'E', 'Other topic', 'practice', 'published'),
  ('00000000-0000-0000-0000-0000000019e4', '00000000-0000-0000-0000-0000000019d1',
   '00000000-0000-0000-0000-0000000019b1', 'mcq', 'E', 'Quiz', 'quiz', 'published');
insert into public.question_choices (question_id, label, body_md)
select q.id, c.label, 'Choice ' || c.label
from public.questions q cross join (values ('A'), ('B'), ('C'), ('D')) c(label)
where q.topic_id in ('00000000-0000-0000-0000-0000000019d1', '00000000-0000-0000-0000-0000000019d2');
insert into private.question_keys (question_id, correct_answer, explanation_md)
select q.id, '{"choice":"B"}', 'Private explanation' from public.questions q
where q.topic_id in ('00000000-0000-0000-0000-0000000019d1', '00000000-0000-0000-0000-0000000019d2');
insert into public.enrollments (user_id, course_id, status, starts_at, expires_at)
select tests.get_supabase_uid(u), '00000000-0000-0000-0000-0000000019c1', 'active',
  now() - interval '1 day', now() + interval '30 days'
from unnest(array['rate_a', 'rate_b']) u;
insert into public.topic_progress (user_id, topic_id, practice_count)
select tests.get_supabase_uid(u), '00000000-0000-0000-0000-0000000019d1', private.setting_int('practice_min')
from unnest(array['rate_a', 'rate_b']) u;
insert into public.attempts (id, user_id, kind, course_id, topic_id) values
  ('00000000-0000-0000-0000-000000001901', tests.get_supabase_uid('rate_a'), 'practice',
   '00000000-0000-0000-0000-0000000019c1', '00000000-0000-0000-0000-0000000019d1'),
  ('00000000-0000-0000-0000-000000001902', tests.get_supabase_uid('rate_b'), 'practice',
   '00000000-0000-0000-0000-0000000019c1', '00000000-0000-0000-0000-0000000019d1'),
  ('00000000-0000-0000-0000-000000001903', tests.get_supabase_uid('rate_a'), 'practice',
   '00000000-0000-0000-0000-0000000019c1', '00000000-0000-0000-0000-0000000019d2');
insert into public.attempt_questions (attempt_id, question_id, position) values
  ('00000000-0000-0000-0000-000000001901', '00000000-0000-0000-0000-0000000019e1', 1),
  ('00000000-0000-0000-0000-000000001901', '00000000-0000-0000-0000-0000000019e2', 2),
  -- Deliberately smuggled into an attempt for T1: must still be rejected.
  ('00000000-0000-0000-0000-000000001901', '00000000-0000-0000-0000-0000000019e3', 3),
  ('00000000-0000-0000-0000-000000001902', '00000000-0000-0000-0000-0000000019e1', 1),
  ('00000000-0000-0000-0000-000000001903', '00000000-0000-0000-0000-0000000019e3', 1);

-- Complete homework before testing the independent quiz-start rate bucket.
select tests.authenticate_as('rate_a');
select public.submit_attempt((public.start_homework('00000000-0000-0000-0000-0000000019d1')->>'attempt_id')::uuid);
select tests.authenticate_as('rate_b');
select public.submit_attempt((public.start_homework('00000000-0000-0000-0000-0000000019d1')->>'attempt_id')::uuid);
select tests.clear_authentication();
reset role;

select is(private.setting_int('rate_answer_per_min'), 30, 'SEC: rate_answer_per_min defaults to 30');
select is(private.setting_int('rate_start_per_min'), 10, 'SEC: rate_start_per_min defaults to 10');
select is(private.setting_int('rate_save_per_min'), 120, 'SEC: rate_save_per_min defaults to 120');
select is(private.setting_int('rate_submit_per_min'), 10, 'SEC: rate_submit_per_min defaults to 10');

select lives_ok($$ select private.hit_rate_limit('t:a', 2, 60) $$, 'SEC: hit_rate_limit allows first call');
select lives_ok($$ select private.hit_rate_limit('t:a', 2, 60) $$, 'SEC: hit_rate_limit allows up to the limit');
select throws_ok($$ select private.hit_rate_limit('t:a', 2, 60) $$, 'P0001', 'rate_limited',
  'SEC: hit_rate_limit rejects calls above the limit');
select lives_ok($$ select private.hit_rate_limit('t:b', 2, 60) $$, 'SEC: keys are independent');
select is((select count from private.rate_limits where key = 't:a'), 2, 'SEC: denied calls do not increase the counter');
insert into private.rate_limits (key, window_start, count) values
  ('t:old', to_timestamp(floor(extract(epoch from now()) / 60) * 60) - interval '1 minute', 99);
select lives_ok($$ select private.hit_rate_limit('t:old', 1, 60) $$, 'SEC: old windows do not exhaust the current window');

update public.settings set value = '1'::jsonb where key = 'rate_answer_per_min';
select tests.authenticate_as('rate_a');
select lives_ok($$ select public.check_practice_answer('00000000-0000-0000-0000-000000001901',
  '00000000-0000-0000-0000-0000000019e1', 'B', 1) $$, 'SEC: first practice answer is allowed');
select throws_ok($$ select public.check_practice_answer('00000000-0000-0000-0000-000000001901',
  '00000000-0000-0000-0000-0000000019e2', 'B', 1) $$, 'P0001', 'rate_limited',
  'SEC: check_practice_answer rate limited on a different question');
select tests.authenticate_as('rate_b');
select lives_ok($$ select public.check_practice_answer('00000000-0000-0000-0000-000000001902',
  '00000000-0000-0000-0000-0000000019e1', 'B', 1) $$, 'SEC: per-user answer quotas are independent');
select tests.clear_authentication();
reset role;

update public.settings set value = '1'::jsonb where key = 'rate_start_per_min';
select tests.authenticate_as('rate_a');
-- A successful first start keeps its increment; gate errors would roll it back.
select lives_ok($$ select public.start_quiz('00000000-0000-0000-0000-0000000019d1') $$,
  'SEC: first quiz start is allowed');
select throws_ok($$ select public.start_quiz('00000000-0000-0000-0000-0000000019d1') $$,
  'P0001', 'rate_limited', 'SEC: start_quiz rate limited');
select lives_ok($$ select public.get_practice_questions('00000000-0000-0000-0000-0000000019d1') $$,
  'SEC: exhausted quiz-start quota does not block another RPC');
select tests.authenticate_as('rate_b');
select lives_ok($$ select public.start_quiz('00000000-0000-0000-0000-0000000019d1') $$,
  'SEC: per-user quiz-start quotas are independent');
select tests.clear_authentication();
reset role;

update public.settings set value = '0'::jsonb
where key in ('rate_start_per_min', 'rate_save_per_min', 'rate_submit_per_min');
select tests.authenticate_as('rate_a');
select throws_ok($$ select public.get_practice_questions('00000000-0000-0000-0000-0000000019d1') $$,
  'P0001', 'rate_limited', 'SEC: get_practice_questions rate limited at zero');
select throws_ok($$ select public.save_answer(null, null, null, 0, false, null, 1) $$,
  'P0001', 'rate_limited', 'SEC: save_answer rate limited before input validation');
select throws_ok($$ select public.submit_attempt(null) $$,
  'P0001', 'rate_limited', 'SEC: submit_attempt rate limited before input validation');
select tests.clear_authentication();
reset role;

update public.settings set value = '30'::jsonb where key = 'rate_answer_per_min';
select tests.authenticate_as('rate_a');
select throws_ok($$ select public.check_practice_answer('00000000-0000-0000-0000-000000001901',
  '00000000-0000-0000-0000-0000000019e3', 'B', 1) $$, 'P0001', 'invalid_input',
  'PRC-01: practice answer must belong to the attempt topic');
select lives_ok($$ select public.check_practice_answer('00000000-0000-0000-0000-000000001903',
  '00000000-0000-0000-0000-0000000019e3', 'A', 1) $$, 'PRC-01: first try on a new question is accepted');
select lives_ok($$ select public.check_practice_answer('00000000-0000-0000-0000-000000001903',
  '00000000-0000-0000-0000-0000000019e3', 'B', 1) $$, 'PRC-01: second try on the same question is accepted');
select tests.clear_authentication();
reset role;
select is((select practice_count from public.topic_progress
  where user_id = tests.get_supabase_uid('rate_a') and topic_id = '00000000-0000-0000-0000-0000000019d2'),
  1, 'PRC-01: same new question answered twice counts once');
select is(has_function_privilege('authenticated', 'private.hit_rate_limit(text,integer,integer)', 'execute'), false,
  'SEC: hit_rate_limit not executable by authenticated');

select * from finish();
rollback;
