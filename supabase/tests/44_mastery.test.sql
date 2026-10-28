-- ANL-01: mastery engine, daily history table and settings.
begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

select tests.create_supabase_user('mastery_a');
select tests.create_supabase_user('mastery_b');

insert into public.courses (id, code, title, slug, is_published, sort) values
  ('00000000-0000-0000-0000-000000004401', 'SAT', 'Mastery Course', 'mastery-course', true, 1);
insert into public.units (id, course_id, title, sort) values
  ('00000000-0000-0000-0000-000000004402', '00000000-0000-0000-0000-000000004401', 'U1', 1);
insert into public.topics (id, course_id, unit_id, title, slug, sort, is_published) values
  ('00000000-0000-0000-0000-000000004403', '00000000-0000-0000-0000-000000004401',
   '00000000-0000-0000-0000-000000004402', 'T1', 'mastery-t1', 1, true);
insert into public.subtopics (id, topic_id, title) values
  ('00000000-0000-0000-0000-000000004404', '00000000-0000-0000-0000-000000004403', 'S1');
insert into public.skills (id, code, name, domain) values
  ('00000000-0000-0000-0000-0000000044a1', 'T44-A', 'Skill A', 'Algebra'),
  ('00000000-0000-0000-0000-0000000044a2', 'T44-B', 'Skill B', 'Algebra'),
  ('00000000-0000-0000-0000-0000000044a3', 'T44-C', 'Skill C', 'Algebra'),
  ('00000000-0000-0000-0000-0000000044a4', 'T44-D', 'Skill D', 'Algebra'),
  ('00000000-0000-0000-0000-0000000044a5', 'T44-E', 'Skill E', 'Algebra');
insert into public.questions (id, topic_id, subtopic_id, type, difficulty, stem_md, pool, status) values
  ('00000000-0000-0000-0000-0000000044b1', '00000000-0000-0000-0000-000000004403', '00000000-0000-0000-0000-000000004404', 'mcq', 'M', 'A', 'practice', 'published'),
  ('00000000-0000-0000-0000-0000000044b2', '00000000-0000-0000-0000-000000004403', '00000000-0000-0000-0000-000000004404', 'mcq', 'E', 'B', 'practice', 'published'),
  ('00000000-0000-0000-0000-0000000044b3', '00000000-0000-0000-0000-000000004403', '00000000-0000-0000-0000-000000004404', 'mcq', 'M', 'C', 'practice', 'published'),
  ('00000000-0000-0000-0000-0000000044b4', '00000000-0000-0000-0000-000000004403', '00000000-0000-0000-0000-000000004404', 'mcq', 'M', 'D', 'practice', 'published'),
  ('00000000-0000-0000-0000-0000000044b5', '00000000-0000-0000-0000-000000004403', '00000000-0000-0000-0000-000000004404', 'mcq', 'M', 'E', 'practice', 'published'),
  ('00000000-0000-0000-0000-0000000044b6', '00000000-0000-0000-0000-000000004403', '00000000-0000-0000-0000-000000004404', 'mcq', 'M', 'Untagged', 'practice', 'published');
insert into public.question_skills (question_id, skill_id) values
  ('00000000-0000-0000-0000-0000000044b1', '00000000-0000-0000-0000-0000000044a1'),
  ('00000000-0000-0000-0000-0000000044b2', '00000000-0000-0000-0000-0000000044a2'),
  ('00000000-0000-0000-0000-0000000044b3', '00000000-0000-0000-0000-0000000044a3'),
  ('00000000-0000-0000-0000-0000000044b4', '00000000-0000-0000-0000-0000000044a4'),
  ('00000000-0000-0000-0000-0000000044b5', '00000000-0000-0000-0000-0000000044a5');

create function pg_temp.m(p_skill int) returns numeric language sql as $$
  select mastery from public.skill_mastery
  where user_id = tests.get_supabase_uid('mastery_a')
    and skill_id = ('00000000-0000-0000-0000-0000000044a' || p_skill)::uuid
$$;

-- Settings
select is((select jsonb_object_agg(key, value) from public.settings where key like 'mastery\_%' or key = 'pass_mark'),
  '{"pass_mark":75,"mastery_alpha":0.15,"mastery_start":50,"mastery_weights":{"quiz":1.2,"mock":1.5,"homework":1.0,"practice":0.5},
    "mastery_weak_below":50,"mastery_difficulty":{"E":0.8,"H":1.2,"M":1.0},
    "mastery_min_attempts":5,"mastery_trend_min_answers":10}'::jsonb,
  'ANL-01: settings_seeded (seven mastery keys plus existing pass_mark)');

-- RLS on the daily history table
select is((select relrowsecurity from pg_class where oid = 'public.skill_mastery_daily'::regclass), true,
  'ANL-01: daily_rls_enabled');

-- Engine math (run as postgres, like the triggers do)
select private.apply_mastery(tests.get_supabase_uid('mastery_a'), '00000000-0000-0000-0000-0000000044b1',
  'quiz', true, 1000, '2026-11-03 10:00:00+00');
select is(pg_temp.m(1), 59.00, 'ANL-01: first_correct_quiz_medium (50 to 59.00)');

select private.apply_mastery(tests.get_supabase_uid('mastery_a'), '00000000-0000-0000-0000-0000000044b2',
  'practice', false, 1000, '2026-11-03 10:00:00+00');
select is(pg_temp.m(2), 47.00, 'ANL-01: incorrect_practice_easy (50 to 47.00)');

select private.apply_mastery(tests.get_supabase_uid('mastery_a'), '00000000-0000-0000-0000-0000000044b3',
  'practice', true, 1000, '2026-11-03 10:00:00+00');
select private.apply_mastery(tests.get_supabase_uid('mastery_a'), '00000000-0000-0000-0000-0000000044b3',
  'review', false, 3000, '2026-11-03 10:05:00+00');
select is((select attempts::text || '/' || correct::text from public.skill_mastery
  where user_id = tests.get_supabase_uid('mastery_a') and skill_id = '00000000-0000-0000-0000-0000000044a3'),
  '2/1', 'ANL-01: attempts_and_correct_counted (review uses the practice weight)');
select is((select avg_time_ms from public.skill_mastery
  where user_id = tests.get_supabase_uid('mastery_a') and skill_id = '00000000-0000-0000-0000-0000000044a3'),
  2000, 'ANL-01: avg_time_ms_running_mean');
select private.apply_mastery(tests.get_supabase_uid('mastery_a'), '00000000-0000-0000-0000-0000000044b3',
  'practice', true, null, '2026-11-03 10:10:00+00');
select is((select avg_time_ms from public.skill_mastery
  where user_id = tests.get_supabase_uid('mastery_a') and skill_id = '00000000-0000-0000-0000-0000000044a3'),
  1333, 'ANL-01: avg_time_ms_running_mean (missing time contributes zero)');
select private.apply_mastery(tests.get_supabase_uid('mastery_a'), '00000000-0000-0000-0000-0000000044b3',
  'practice', true, 4000, '2026-11-03 10:15:00+00');
select is((select avg_time_ms from public.skill_mastery
  where user_id = tests.get_supabase_uid('mastery_a') and skill_id = '00000000-0000-0000-0000-0000000044a3'),
  2000, 'ANL-01: avg_time_ms_running_mean (timed answer after missing time)');

-- Clamp: an absurd alpha must not leave 0..100.
update public.settings set value = '5' where key = 'mastery_alpha';
select private.apply_mastery(tests.get_supabase_uid('mastery_a'), '00000000-0000-0000-0000-0000000044b4',
  'quiz', true, 1, '2026-11-03 10:00:00+00');
select is(pg_temp.m(4), 100.00, 'ANL-01: clamped_0_100 at 100');
select private.apply_mastery(tests.get_supabase_uid('mastery_a'), '00000000-0000-0000-0000-0000000044b4',
  'quiz', false, 1, '2026-11-03 11:00:00+00');
select is(pg_temp.m(4), 0.00, 'ANL-01: clamped_0_100 at 0');
update public.settings set value = '0.15' where key = 'mastery_alpha';

-- Daily history: one row per user, skill and day, holding the latest value.
select private.apply_mastery(tests.get_supabase_uid('mastery_a'), '00000000-0000-0000-0000-0000000044b5',
  'homework', true, 1, '2026-11-03 10:00:00+00');
select private.apply_mastery(tests.get_supabase_uid('mastery_a'), '00000000-0000-0000-0000-0000000044b5',
  'homework', false, 1, '2026-11-03 18:00:00+00');
select is((select array_agg(day::text || '=' || mastery::text)
  from public.skill_mastery_daily
  where user_id = tests.get_supabase_uid('mastery_a') and skill_id = '00000000-0000-0000-0000-0000000044a5'),
  array['2026-11-03=48.88'], 'ANL-01: daily_upserted_same_day (one row, latest value)');

-- Untagged question changes nothing.
select private.apply_mastery(tests.get_supabase_uid('mastery_a'), '00000000-0000-0000-0000-0000000044b6',
  'quiz', true, 1, '2026-11-03 10:00:00+00');
select is((select count(*)::int from public.skill_mastery where user_id = tests.get_supabase_uid('mastery_a')), 5,
  'ANL-01: untagged_question_noop');

-- Student reads own history only; no client writes; engine not callable.
select tests.authenticate_as('mastery_b');
select is((select count(*)::int from public.skill_mastery_daily), 0,
  'ANL-01: daily_student_reads_own_only (B cannot see A)');
select tests.authenticate_as('mastery_a');
select cmp_ok((select count(*)::int from public.skill_mastery_daily), '>', 0,
  'ANL-01: student A sees own daily history');
select throws_ok($$ insert into public.skill_mastery_daily (user_id, skill_id, day, mastery)
  values (auth.uid(), '00000000-0000-0000-0000-0000000044a1', current_date, 99) $$,
  '42501', null, 'ANL-01: daily_no_client_writes');
select throws_ok($$ select private.apply_mastery(auth.uid(), '00000000-0000-0000-0000-0000000044b1', 'quiz', true, 1, now()) $$,
  '42501', null, 'ANL-01: apply_not_executable_by_authenticated');
select tests.clear_authentication();
reset role;

select * from finish();
rollback;
