-- PRC-03 / SEC: expiry and nightly maintenance. From templates/test.sql.
begin;
create extension if not exists pgtap with schema extensions;
select plan(23);

select tests.create_supabase_user('cron_student');

insert into public.courses (id, code, title, slug, is_published, sort) values
  ('00000000-0000-0000-0000-0000000018c1', 'SAT', 'Cron Course', 'cron-course', true, 1);
insert into public.units (id, course_id, title, sort) values
  ('00000000-0000-0000-0000-0000000018a1', '00000000-0000-0000-0000-0000000018c1', 'U1', 1);
insert into public.topics (id, course_id, unit_id, title, slug, sort, is_published, is_free_preview) values
  ('00000000-0000-0000-0000-0000000018d1', '00000000-0000-0000-0000-0000000018c1',
   '00000000-0000-0000-0000-0000000018a1', 'T1', 'cron-t1', 1, true, true);
insert into public.subtopics (id, topic_id, title) values
  ('00000000-0000-0000-0000-0000000018b1', '00000000-0000-0000-0000-0000000018d1', 'S1');
insert into public.questions (id, topic_id, subtopic_id, type, difficulty, stem_md, pool, status) values
  ('00000000-0000-0000-0000-0000000018e1', '00000000-0000-0000-0000-0000000018d1',
   '00000000-0000-0000-0000-0000000018b1', 'mcq', 'E', 'Quiz MCQ', 'quiz', 'published'),
  ('00000000-0000-0000-0000-0000000018e2', '00000000-0000-0000-0000-0000000018d1',
   '00000000-0000-0000-0000-0000000018b1', 'mcq', 'E', 'Practice MCQ', 'practice', 'published');
insert into private.question_keys (question_id, correct_answer, explanation_md) values
  ('00000000-0000-0000-0000-0000000018e1', '{"choice":"B"}', 'Quiz explanation');

-- now() is transaction-stable; fixture deadlines cannot drift during this suite.
update public.settings set value = '30'::jsonb where key = 'save_grace_s';
insert into public.attempts (id, user_id, kind, course_id, topic_id, status, started_at, time_limit_s, submitted_at)
select f.id::uuid, tests.get_supabase_uid('cron_student'), f.kind::public.attempt_kind,
  '00000000-0000-0000-0000-0000000018c1', '00000000-0000-0000-0000-0000000018d1',
  f.status::public.attempt_status, now() - f.age, f.time_limit_s, f.submitted_at
from (values
  ('00000000-0000-0000-0000-000000001801', 'quiz', 'in_progress', interval '1 hour', 60, null::timestamptz),
  ('00000000-0000-0000-0000-000000001802', 'quiz', 'in_progress', interval '80 seconds', 60, null::timestamptz),
  ('00000000-0000-0000-0000-000000001803', 'quiz', 'submitted', interval '1 hour', 60, now() - interval '59 minutes'),
  ('00000000-0000-0000-0000-000000001804', 'practice', 'in_progress', interval '2 days', null, null::timestamptz),
  ('00000000-0000-0000-0000-000000001805', 'practice', 'in_progress', interval '2 days', null, null::timestamptz),
  ('00000000-0000-0000-0000-000000001806', 'practice', 'in_progress', interval '2 days', null, null::timestamptz),
  ('00000000-0000-0000-0000-000000001807', 'practice', 'in_progress', interval '1 hour', null, null::timestamptz),
  ('00000000-0000-0000-0000-000000001808', 'practice', 'submitted', interval '2 days', null, now() - interval '1 day')
) f(id, kind, status, age, time_limit_s, submitted_at);
insert into public.attempt_questions (attempt_id, question_id, position)
select a.id, case when a.kind = 'quiz' then '00000000-0000-0000-0000-0000000018e1'::uuid
  else '00000000-0000-0000-0000-0000000018e2'::uuid end, 1
from public.attempts a where a.user_id = tests.get_supabase_uid('cron_student');
insert into public.attempt_answers (attempt_id, question_id, answer, answered_at) values
  ('00000000-0000-0000-0000-000000001805', '00000000-0000-0000-0000-0000000018e2', '{"value":"B"}', now() - interval '1 hour'),
  ('00000000-0000-0000-0000-000000001806', '00000000-0000-0000-0000-0000000018e2', '{"value":"B"}', now() - interval '25 hours');
insert into private.rate_limits (key, window_start, count) values
  ('test:cron:18', now() - interval '2 days', 1),
  ('test:cron:18', now(), 1);

select is(private.expire_overdue_attempts(), 1, 'PRC-03: overdue quiz is finished by cron');
select is((select status::text from public.attempts where id = '00000000-0000-0000-0000-000000001801'),
  'submitted', 'PRC-03: overdue quiz status is submitted');
select is((select submitted_at from public.attempts where id = '00000000-0000-0000-0000-000000001801'),
  (select started_at + interval '60 seconds' from public.attempts where id = '00000000-0000-0000-0000-000000001801'),
  'PRC-03: overdue quiz submission uses the original deadline');
select ok((select meta -> 'report' is not null from public.attempts where id = '00000000-0000-0000-0000-000000001801'),
  'PRC-03: overdue quiz has a report');
select is((select quiz_last_failed_at from public.topic_progress
  where user_id = tests.get_supabase_uid('cron_student') and topic_id = '00000000-0000-0000-0000-0000000018d1'),
  (select started_at + interval '60 seconds' from public.attempts where id = '00000000-0000-0000-0000-000000001801'),
  'PRC-03: unanswered overdue quiz records failure at its deadline');
select is((select status::text from public.attempts where id = '00000000-0000-0000-0000-000000001802'),
  'in_progress', 'PRC-03: quiz inside grace is not expired');
select lives_ok($$ select private.expire_overdue_attempts() $$, 'PRC-03: submitted quiz is skipped');
select is((select submitted_at from public.attempts where id = '00000000-0000-0000-0000-000000001803'),
  now() - interval '59 minutes', 'PRC-03: submitted quiz timestamp is unchanged');
select is((select status::text from public.attempts where id = '00000000-0000-0000-0000-000000001804'),
  'in_progress', 'PRC-03: practice attempts are not touched by expiry');

select lives_ok($$ select private.nightly_cleanup() $$, 'PRC-03: nightly cleanup runs');
select is((select status::text from public.attempts where id = '00000000-0000-0000-0000-000000001804'),
  'abandoned', 'PRC-03: stale practice abandoned');
select is((select status::text from public.attempts where id = '00000000-0000-0000-0000-000000001805'),
  'in_progress', 'PRC-03: recent answer keeps old practice active');
select is((select status::text from public.attempts where id = '00000000-0000-0000-0000-000000001806'),
  'abandoned', 'PRC-03: stale last answer abandons practice');
select is((select status::text from public.attempts where id = '00000000-0000-0000-0000-000000001807'),
  'in_progress', 'PRC-03: recent unanswered practice stays active');
select is((select status::text from public.attempts where id = '00000000-0000-0000-0000-000000001808'),
  'submitted', 'PRC-03: cleanup leaves submitted practice untouched');
select is((select count(*)::int from private.rate_limits
  where key = 'test:cron:18' and window_start = now() - interval '2 days'),
  0, 'SEC: old rate-limit windows purged');
select is((select count(*)::int from private.rate_limits where key = 'test:cron:18' and window_start = now()),
  1, 'SEC: current rate-limit windows kept');
select is((select count(*)::int from cron.job where jobname in ('expire-attempts', 'nightly-cleanup')),
  2, 'PRC-03: cron jobs scheduled');
select results_eq($$ select jobname, schedule, command from cron.job
  where jobname in ('expire-attempts', 'nightly-cleanup') order by jobname $$,
  $$ values ('expire-attempts'::text, '* * * * *'::text, 'select private.expire_overdue_attempts()'::text),
            ('nightly-cleanup'::text, '0 2 * * *'::text, 'select private.nightly_cleanup()'::text) $$,
  'PRC-03: jobs have the contracted schedules and functions');
select is((select value from public.settings where key = 'practice_stale_h'), '24'::jsonb,
  'PRC-03: practice_stale_h defaults to 24');
select is(has_function_privilege('authenticated', 'private.expire_overdue_attempts()', 'execute'), false,
  'SEC: cron expiry not executable by authenticated');
select is(has_function_privilege('authenticated', 'private.nightly_cleanup()', 'execute'), false,
  'SEC: nightly cleanup not executable by authenticated');
select is(private.expire_overdue_attempts(), 0, 'PRC-03: repeated expiry does not grade twice');

select * from finish();
rollback;
