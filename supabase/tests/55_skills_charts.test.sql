-- ANL-01b: get_my_skills chart fields (strong_at, accuracy, avg_time_ms, history, domains). From templates/test.sql.
begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

select tests.create_supabase_user(u) from unnest(array['ch_a', 'ch_b', 'ch_c', 'ch_none']) u;

create function pg_temp.id(p_n int) returns uuid language sql immutable as $$
  select ('00000000-0000-0000-0000-0000000055' || lpad(p_n::text, 2, '0'))::uuid
$$;
-- ids: course 1, unit 2, topic 3, subtopic 4, skills 11-14, questions 21-24
insert into public.courses (id, code, title, slug, is_published, sort) values
  (pg_temp.id(1), 'SAT', 'Charts', 'charts-a', true, 1);
insert into public.units (id, course_id, title, sort) values (pg_temp.id(2), pg_temp.id(1), 'Unit', 1);
insert into public.topics (id, course_id, unit_id, title, slug, sort, is_published, is_free_preview) values
  (pg_temp.id(3), pg_temp.id(1), pg_temp.id(2), 'Topic', 'charts-t1', 1, true, false);
insert into public.subtopics (id, topic_id, title) values (pg_temp.id(4), pg_temp.id(3), 'S');
insert into public.skills (id, code, name, domain) values
  (pg_temp.id(11), 'T55-1', 'Linear',     'Algebra'),
  (pg_temp.id(12), 'T55-2', 'Systems',    'Algebra'),
  (pg_temp.id(13), 'T55-3', 'Angles',     'Geometry'),
  (pg_temp.id(14), 'T55-4', 'Statistics', 'Data');
insert into public.questions (id, topic_id, subtopic_id, type, difficulty, stem_md, pool, status)
select pg_temp.id(20 + n), pg_temp.id(3), pg_temp.id(4), 'mcq', 'M', 'Q' || n, 'practice', 'published'
from generate_series(1, 4) n;
insert into public.question_skills (question_id, skill_id)
select pg_temp.id(20 + n), pg_temp.id(10 + n) from generate_series(1, 4) n;

insert into public.enrollments (user_id, course_id, status, starts_at, expires_at)
select tests.get_supabase_uid(u), pg_temp.id(1), 'active', now() - interval '1 day', now() + interval '30 days'
from unnest(array['ch_a', 'ch_b', 'ch_c', 'ch_none']) u;

-- ch_a: T55-1 weak (3/6 correct, 2.0 s), T55-3 strong (4/5, 1.5 s), T55-2 and T55-4 never practised.
-- ch_b: another student with 9/9 on T55-1 and a flat-zero history that must never show up for ch_a.
-- ch_c: two practised skills in Algebra so the domain mean is a rounded average.
insert into public.skill_mastery (user_id, skill_id, mastery, attempts, correct, avg_time_ms) values
  (tests.get_supabase_uid('ch_a'), pg_temp.id(11), 40, 6, 3, 2000),
  (tests.get_supabase_uid('ch_a'), pg_temp.id(13), 80, 5, 4, 1500),
  (tests.get_supabase_uid('ch_b'), pg_temp.id(11), 95, 9, 9, 900),
  (tests.get_supabase_uid('ch_c'), pg_temp.id(11), 40,    6, 3, 1000),
  (tests.get_supabase_uid('ch_c'), pg_temp.id(12), 45.55, 1, 0, 3000);

create function pg_temp.w(p_weeks int) returns date language sql stable as $$
  select (date_trunc('week', now() at time zone 'UTC')::date - 7 * p_weeks)
$$;
insert into public.skill_mastery_daily (user_id, skill_id, day, mastery) values
  (tests.get_supabase_uid('ch_a'), pg_temp.id(11), pg_temp.w(2) + 1, 30),
  (tests.get_supabase_uid('ch_a'), pg_temp.id(11), pg_temp.w(1) + 0, 40),
  (tests.get_supabase_uid('ch_a'), pg_temp.id(11), pg_temp.w(1) + 2, 50),
  (tests.get_supabase_uid('ch_a'), pg_temp.id(11), pg_temp.w(10),    99),   -- older than 8 weeks
  (tests.get_supabase_uid('ch_a'), pg_temp.id(13), pg_temp.w(1) + 1, 80),   -- a single week only
  (tests.get_supabase_uid('ch_b'), pg_temp.id(11), pg_temp.w(2),      0),
  (tests.get_supabase_uid('ch_b'), pg_temp.id(11), pg_temp.w(1),      0);

create temp table ctx (k text primary key, v jsonb);
grant select, insert on ctx to authenticated;
grant execute on function pg_temp.id(int) to authenticated;
grant execute on function pg_temp.w(int) to authenticated;

select tests.authenticate_as('ch_a');
insert into ctx values ('a', public.get_my_skills(pg_temp.id(1)));
select tests.authenticate_as('ch_b');
insert into ctx values ('b', public.get_my_skills(pg_temp.id(1)));
select tests.authenticate_as('ch_c');
insert into ctx values ('c', public.get_my_skills(pg_temp.id(1)));
select tests.authenticate_as('ch_none');
insert into ctx values ('none', public.get_my_skills(pg_temp.id(1)));
select tests.clear_authentication();
reset role;

-- Shape: additive keys present, old keys kept
select is((select array_agg(key order by key) from ctx, jsonb_object_keys(v) key where k = 'a'),
  array['domains', 'skills', 'summary', 'topics', 'trend', 'weak'], 'ANL-01b: top-level keys (domains added, nothing removed)');
select is((select v -> 'summary' -> 'strong_at' from ctx where k = 'a'),
  (select to_jsonb((value #>> '{}')::int) from public.settings where key = 'pass_mark'),
  'ANL-01b: summary.strong_at equals the pass_mark setting');
select is((select array_agg(key order by key) from ctx, jsonb_array_elements(v -> 'skills') s, jsonb_object_keys(s) key
  where k = 'a' and s ->> 'code' = 'T55-1'),
  array['accuracy', 'attempts', 'avg_time_ms', 'band', 'code', 'domain', 'history', 'mastery', 'name'],
  'ANL-01b: skill item keys (accuracy, avg_time_ms, history added)');
select is((select array_agg(key order by key) from ctx, jsonb_array_elements(v -> 'domains') d, jsonb_object_keys(d) key
  where k = 'a' and d ->> 'domain' = 'Data'),
  array['band', 'domain', 'mean', 'practised', 'total'], 'ANL-01b: domain item keys');

-- Accuracy and average time
select is((select jsonb_object_agg(s ->> 'code', jsonb_build_array(s -> 'accuracy', s -> 'avg_time_ms'))
  from ctx, jsonb_array_elements(v -> 'skills') s where k = 'a'),
  '{"T55-1":[50.0,2000],"T55-2":[null,null],"T55-3":[80.0,1500],"T55-4":[null,null]}'::jsonb,
  'ANL-01b: accuracy is correct/attempts*100 (1 decimal), avg_time_ms from skill_mastery, both null when unpractised');
select is((select s -> 'accuracy' from ctx, jsonb_array_elements(v -> 'skills') s where k = 'c' and s ->> 'code' = 'T55-2'),
  '0.0'::jsonb, 'ANL-01b: accuracy 0 stays 0, not null, once attempted');

-- History
select is((select s -> 'history' from ctx, jsonb_array_elements(v -> 'skills') s where k = 'a' and s ->> 'code' = 'T55-1'),
  jsonb_build_array(jsonb_build_object('week_start', pg_temp.w(2), 'mastery', 30.0),
                    jsonb_build_object('week_start', pg_temp.w(1), 'mastery', 45.0)),
  'ANL-01b: history is weekly means, oldest first, last 8 weeks only');
select is((select s -> 'history' from ctx, jsonb_array_elements(v -> 'skills') s where k = 'a' and s ->> 'code' = 'T55-3'),
  '[]'::jsonb, 'ANL-01b: history is empty with fewer than two weeks');
select is((select s -> 'history' from ctx, jsonb_array_elements(v -> 'skills') s where k = 'none' and s ->> 'code' = 'T55-1'),
  '[]'::jsonb, 'ANL-01b: history is empty for a student with no data');

-- Domains
select is((select v -> 'domains' from ctx where k = 'a'),
  '[{"domain":"Algebra","mean":40.0,"band":"weak","practised":1,"total":2},
    {"domain":"Data","mean":null,"band":"thin","practised":0,"total":1},
    {"domain":"Geometry","mean":80.0,"band":"strong","practised":1,"total":1}]'::jsonb,
  'ANL-01b: domains ordered by name with mean of practised skills, band, practised and total (never-practised domain is null/thin)');
select is((select d from ctx, jsonb_array_elements(v -> 'domains') d where k = 'c' and d ->> 'domain' = 'Algebra'),
  '{"domain":"Algebra","mean":42.8,"band":"weak","practised":2,"total":2}'::jsonb,
  'ANL-01b: domain mean is rounded to one decimal (42.775 -> 42.8)');
select is((select d ->> 'band' from ctx, jsonb_array_elements(v -> 'domains') d where k = 'c' and d ->> 'domain' = 'Algebra'),
  private.mastery_band(42.775, 7, private.setting_int('mastery_weak_below')::numeric,
    private.setting_int('mastery_min_attempts'), private.setting_int('pass_mark')::numeric),
  'ANL-01b: domain band comes from private.mastery_band over the mean and summed attempts');

-- Another student's rows never leak
select is((select jsonb_build_array(s -> 'accuracy', s -> 'avg_time_ms', s -> 'history')
  from ctx, jsonb_array_elements(v -> 'skills') s where k = 'b' and s ->> 'code' = 'T55-1'),
  jsonb_build_array(100.0, 900, jsonb_build_array(
    jsonb_build_object('week_start', pg_temp.w(2), 'mastery', 0.0),
    jsonb_build_object('week_start', pg_temp.w(1), 'mastery', 0.0))),
  'ANL-01b: each student sees only their own accuracy, time and history');

-- Grants stay as before
select is((has_function_privilege('anon', 'public.get_my_skills(uuid)', 'execute'),
           has_function_privilege('authenticated', 'public.get_my_skills(uuid)', 'execute')),
  (false, true), 'ANL-01b: get_my_skills stays executable by authenticated only');

select * from finish();
rollback;
