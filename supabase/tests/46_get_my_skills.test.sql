-- ANL-01: get_my_skills RPC. From templates/test.sql.
begin;
create extension if not exists pgtap with schema extensions;
select plan(23);

select tests.create_supabase_user(u) from unnest(array[
  'get_a', 'get_exp', 'get_exp2', 'get_none', 'get_weak', 'get_trend']) u;

create function pg_temp.id(p_n int) returns uuid language sql immutable as $$
  select ('00000000-0000-0000-0000-0000000046' || lpad(p_n::text, 2, '0'))::uuid
$$;
-- ids: courses 1-2, units 3-4, topics 5-7, subtopics 15-17, skills 21-25, questions 31-38 (A) and 41-42 (B),
-- attempts 51-54 (get_a) and 61-62 (get_trend)
insert into public.courses (id, code, title, slug, is_published, sort) values
  (pg_temp.id(1), 'SAT', 'Skills A', 'skills-a', true, 1),
  (pg_temp.id(2), 'EST', 'Skills B', 'skills-b', true, 2);
insert into public.units (id, course_id, title, sort) values
  (pg_temp.id(3), pg_temp.id(1), 'Unit One', 1),
  (pg_temp.id(4), pg_temp.id(2), 'Unit B', 1);
insert into public.topics (id, course_id, unit_id, title, slug, sort, is_published, is_free_preview) values
  (pg_temp.id(5), pg_temp.id(1), pg_temp.id(3), 'Linear equations', 'skills-a-t1', 1, true, false),
  (pg_temp.id(6), pg_temp.id(1), pg_temp.id(3), 'Geometry', 'skills-a-t2', 2, true, false),
  (pg_temp.id(7), pg_temp.id(2), pg_temp.id(4), 'B topic', 'skills-b-t1', 1, true, false);
insert into public.subtopics (id, topic_id, title) values
  (pg_temp.id(15), pg_temp.id(5), 'S1'), (pg_temp.id(16), pg_temp.id(6), 'S2'), (pg_temp.id(17), pg_temp.id(7), 'S3');
insert into public.skills (id, code, name, domain) values
  (pg_temp.id(21), 'T46-1', 'Linear solve', 'Algebra'),
  (pg_temp.id(22), 'T46-2', 'Systems',      'Algebra'),
  (pg_temp.id(23), 'T46-3', 'Angles',       'Geometry'),
  (pg_temp.id(24), 'T46-4', 'Only in B',    'Data'),
  (pg_temp.id(25), 'T46-5', 'Thin skill',   'Geometry');
-- Q31 E practice (SK1) · Q32 M practice (SK1) · Q33 H quiz-pool (SK2) · Q34 M practice untagged
-- Q35 E practice (SK3) · Q36 M practice (SK3) · Q37 draft (SK3) · Q38 E practice (SK5)
insert into public.questions (id, topic_id, subtopic_id, type, difficulty, stem_md, pool, status)
select pg_temp.id(v.n), pg_temp.id(v.t), pg_temp.id(v.t + 10), 'mcq', v.d::public.difficulty, 'Q' || v.n,
       v.pool::public.question_pool, v.st::public.question_status
from (values
  (31, 5, 'E', 'practice', 'published'), (32, 5, 'M', 'practice', 'published'),
  (33, 5, 'H', 'quiz',     'published'), (34, 5, 'M', 'practice', 'published'),
  (35, 6, 'E', 'practice', 'published'), (36, 6, 'M', 'practice', 'published'),
  (37, 6, 'M', 'practice', 'draft'),     (38, 6, 'E', 'practice', 'published'),
  (41, 7, 'E', 'practice', 'published'), (42, 7, 'M', 'practice', 'published')
) v(n, t, d, pool, st);
insert into public.question_skills (question_id, skill_id) values
  (pg_temp.id(31), pg_temp.id(21)), (pg_temp.id(32), pg_temp.id(21)), (pg_temp.id(33), pg_temp.id(22)),
  (pg_temp.id(35), pg_temp.id(23)), (pg_temp.id(36), pg_temp.id(23)), (pg_temp.id(37), pg_temp.id(23)),
  (pg_temp.id(38), pg_temp.id(25)),
  (pg_temp.id(41), pg_temp.id(24)), (pg_temp.id(42), pg_temp.id(21));
insert into private.question_keys (question_id, correct_answer, explanation_md)
select q.id, '{"choice":"B"}', 'Private explanation' from public.questions q
where q.topic_id in (pg_temp.id(5), pg_temp.id(6), pg_temp.id(7));

insert into public.enrollments (user_id, course_id, status, starts_at, expires_at)
select tests.get_supabase_uid(u), c, 'active', now() - interval '1 day', now() + interval '30 days'
from unnest(array['get_a', 'get_weak', 'get_trend']) u
cross join unnest(array[pg_temp.id(1)]) c;
insert into public.enrollments (user_id, course_id, status, starts_at, expires_at) values
  (tests.get_supabase_uid('get_a'), pg_temp.id(2), 'active', now() - interval '1 day', now() + interval '30 days'),
  (tests.get_supabase_uid('get_exp'),  pg_temp.id(1), 'active',  now() - interval '9 days', now() - interval '1 day'),
  (tests.get_supabase_uid('get_exp2'), pg_temp.id(1), 'expired', now() - interval '9 days', now() + interval '1 day');

-- Mastery: get_a (all thresholds + a skill that only exists in course B), get_weak (four weak skills).
insert into public.skill_mastery (user_id, skill_id, mastery, attempts, correct) values
  (tests.get_supabase_uid('get_a'), pg_temp.id(21), 49, 6, 3),
  (tests.get_supabase_uid('get_a'), pg_temp.id(22), 50, 6, 3),
  (tests.get_supabase_uid('get_a'), pg_temp.id(23), 75, 5, 4),
  (tests.get_supabase_uid('get_a'), pg_temp.id(24), 10, 9, 1),
  (tests.get_supabase_uid('get_a'), pg_temp.id(25), 80, 4, 4),
  (tests.get_supabase_uid('get_weak'), pg_temp.id(21), 20, 6, 1),
  (tests.get_supabase_uid('get_weak'), pg_temp.id(22), 30, 6, 2),
  (tests.get_supabase_uid('get_weak'), pg_temp.id(23), 10, 6, 0),
  (tests.get_supabase_uid('get_weak'), pg_temp.id(25), 40, 6, 2);

-- Graded answers inserted without the mastery triggers (mastery above is set by hand).
alter table public.attempt_answers disable trigger attempt_answers_mastery;
insert into public.attempts (id, user_id, kind, course_id, topic_id, status, time_limit_s) values
  (pg_temp.id(51), tests.get_supabase_uid('get_a'), 'practice', pg_temp.id(1), pg_temp.id(5), 'submitted', null),
  (pg_temp.id(52), tests.get_supabase_uid('get_a'), 'practice', pg_temp.id(1), pg_temp.id(5), 'submitted', null),
  (pg_temp.id(53), tests.get_supabase_uid('get_a'), 'quiz',     pg_temp.id(1), pg_temp.id(5), 'submitted', 600),
  (pg_temp.id(54), tests.get_supabase_uid('get_a'), 'practice', pg_temp.id(2), pg_temp.id(7), 'submitted', null),
  (pg_temp.id(61), tests.get_supabase_uid('get_trend'), 'practice', pg_temp.id(1), pg_temp.id(5), 'submitted', null),
  (pg_temp.id(62), tests.get_supabase_uid('get_trend'), 'practice', pg_temp.id(1), pg_temp.id(5), 'submitted', null);
insert into public.attempt_questions (attempt_id, question_id, position) values
  (pg_temp.id(51), pg_temp.id(31), 1), (pg_temp.id(51), pg_temp.id(32), 2),
  (pg_temp.id(52), pg_temp.id(31), 1),
  (pg_temp.id(53), pg_temp.id(35), 1), (pg_temp.id(53), pg_temp.id(33), 2),
  (pg_temp.id(54), pg_temp.id(41), 1);
insert into public.attempt_answers (attempt_id, question_id, answer, is_correct, time_ms, answered_at) values
  (pg_temp.id(51), pg_temp.id(31), '{"tries":["B"]}', true,  1000, now()),
  (pg_temp.id(51), pg_temp.id(32), '{"tries":["A"]}', false, 1000, now()),
  (pg_temp.id(52), pg_temp.id(31), '{"tries":["B"]}', true,  1000, now()),
  (pg_temp.id(53), pg_temp.id(35), '{"value":"B"}',   true,  1000, now()),
  (pg_temp.id(53), pg_temp.id(33), '{"value":"A"}',   false, 1000, now()),
  (pg_temp.id(54), pg_temp.id(41), '{"tries":["B"]}', true,  1000, now());
insert into public.attempt_questions (attempt_id, question_id, position)
select a, pg_temp.id(q), p from unnest(array[pg_temp.id(61), pg_temp.id(62)]) a
cross join (values (31, 1), (32, 2), (33, 3), (35, 4), (36, 5)) v(q, p);
insert into public.attempt_answers (attempt_id, question_id, answer, is_correct, time_ms, answered_at)
select a, pg_temp.id(q), '{"tries":["B"]}', true, 1000, now() from unnest(array[pg_temp.id(61), pg_temp.id(62)]) a
cross join (values (31), (32), (33), (35), (36)) v(q);
alter table public.attempt_answers enable trigger attempt_answers_mastery;

-- Trend history for get_trend: weeks relative to the current week (Monday start, UTC).
create function pg_temp.w(p_weeks int) returns date language sql stable as $$
  select (date_trunc('week', now() at time zone 'UTC')::date - 7 * p_weeks)
$$;
insert into public.skill_mastery_daily (user_id, skill_id, day, mastery) values
  (tests.get_supabase_uid('get_trend'), pg_temp.id(21), pg_temp.w(2) + 1, 40),
  (tests.get_supabase_uid('get_trend'), pg_temp.id(21), pg_temp.w(1) + 0, 50),
  (tests.get_supabase_uid('get_trend'), pg_temp.id(21), pg_temp.w(1) + 2, 60),
  (tests.get_supabase_uid('get_trend'), pg_temp.id(22), pg_temp.w(1) + 1, 70),
  (tests.get_supabase_uid('get_trend'), pg_temp.id(24), pg_temp.w(1) + 1, 0),   -- skill of course B only
  (tests.get_supabase_uid('get_trend'), pg_temp.id(21), pg_temp.w(10),   99);   -- older than 8 weeks

create temp table ctx (k text primary key, v jsonb);
grant select, insert on ctx to authenticated;
grant execute on function pg_temp.id(int) to authenticated;

-- Enough weekly history to prove the graded-answer minimum actually hides a trend.
insert into public.skill_mastery_daily (user_id, skill_id, day, mastery) values
  (tests.get_supabase_uid('get_a'), pg_temp.id(21), pg_temp.w(2), 40),
  (tests.get_supabase_uid('get_a'), pg_temp.id(21), pg_temp.w(1), 60);

-- Access and permissions
select tests.clear_authentication();
set local role authenticated;
select throws_ok($$ select public.get_my_skills('00000000-0000-0000-0000-000000004601') $$,
  'P0001', 'not_authenticated', 'ANL-01: not_authenticated_raises');
reset role;
select tests.authenticate_as('get_none');
select throws_ok($$ select public.get_my_skills('00000000-0000-0000-0000-000000004601') $$,
  'P0001', 'not_enrolled', 'ANL-01: not_enrolled_raises');
select tests.authenticate_as('get_exp');
select throws_ok($$ select public.get_my_skills('00000000-0000-0000-0000-000000004601') $$,
  'P0001', 'access_expired', 'ANL-01: expired_access_raises (past expires_at)');
select tests.authenticate_as('get_exp2');
select throws_ok($$ select public.get_my_skills('00000000-0000-0000-0000-000000004601') $$,
  'P0001', 'access_expired', 'ANL-01: expired_access_raises (status expired)');
select tests.authenticate_as('get_a');
select throws_ok($$ select public.get_my_skills(null) $$, 'P0001', 'invalid_input', 'ANL-01: null course is invalid_input');

set local request.headers = '{"x-device-id":"unregistered-device"}';
select throws_ok($$ select public.get_my_skills('00000000-0000-0000-0000-000000004601') $$,
  'P0001', 'access_expired', 'ANL-01: get_my_skills honors has_access device restriction');
set local request.headers = '{}';

-- Main payload for get_a
insert into ctx values ('a', public.get_my_skills('00000000-0000-0000-0000-000000004601'));
select tests.clear_authentication();
reset role;
-- A competing topic has fewer practice questions for the same skill.
insert into public.question_skills values (pg_temp.id(35), pg_temp.id(21));
select tests.authenticate_as('get_weak');
insert into ctx values ('weak', public.get_my_skills('00000000-0000-0000-0000-000000004601'));
select tests.clear_authentication();
reset role;
delete from public.question_skills where question_id = pg_temp.id(35) and skill_id = pg_temp.id(21);
select tests.authenticate_as('get_trend');
insert into ctx values ('trend', public.get_my_skills('00000000-0000-0000-0000-000000004601'));
select tests.clear_authentication();
reset role;

select is((select array_agg(key order by key) from ctx, jsonb_object_keys(v) key where k = 'a'),
  array['skills', 'summary', 'topics', 'trend', 'weak'], 'ANL-01: shape_keys_exact (top-level keys)');
select is((select v::text ~* '"(question|stem|answer|key|explanation)[a-z_]*"\s*:' from ctx where k = 'a'), false,
  'ANL-01: shape_keys_exact (no question, stem, answer, key or explanation fields anywhere)');

select is((select jsonb_object_agg(s ->> 'code', s ->> 'band') from ctx, jsonb_array_elements(v -> 'skills') s where k = 'a'),
  '{"T46-1":"weak","T46-2":"building","T46-3":"strong","T46-5":"thin"}'::jsonb,
  'ANL-01: bands_from_settings (49 weak, 50 building, 75 strong, 4 attempts thin)');

select is((select array_agg(s ->> 'code' order by ord) from ctx, jsonb_array_elements(v -> 'weak') with ordinality w(s, ord) where k = 'weak'),
  array['T46-3', 'T46-1', 'T46-2'], 'ANL-01: weak_top3_with_topic_target (three lowest weak skills, lowest first)');
select is((select jsonb_agg(jsonb_build_array(s ->> 'code', s ->> 'topic_title') order by ord)
  from ctx, jsonb_array_elements(v -> 'weak') with ordinality w(s, ord) where k = 'weak'),
  '[["T46-3","Geometry"],["T46-1","Linear equations"],["T46-2","Linear equations"]]'::jsonb,
  'ANL-01: weak target is the course topic with most practice questions of the skill (quiz-only skill falls back to its topic)');

select is((select v -> 'trend' from ctx where k = 'a'), '[]'::jsonb,
  'ANL-01: trend_thin_under_min_answers (5 graded answers, no trend)');
select is((select v -> 'trend' from ctx where k = 'trend'),
  jsonb_build_array(jsonb_build_object('week_start', pg_temp.w(2), 'mastery', 40.0),
                    jsonb_build_object('week_start', pg_temp.w(1), 'mastery', 60.0)),
  'ANL-01: trend_weekly_mean (weekly mean of this course skills, last 8 weeks, no other course)');
delete from public.skill_mastery_daily
  where user_id = tests.get_supabase_uid('get_trend') and day = pg_temp.w(2) + 1;
select tests.authenticate_as('get_trend');
select is(public.get_my_skills(pg_temp.id(1)) -> 'trend', '[]'::jsonb,
  'ANL-01: a single week of data gives an empty trend');

select is((select v from ctx where k = 'a'),
  jsonb_build_object(
    'summary', jsonb_build_object('solved',2,'total',7,'graded_answers',5),
    'skills', '[{"code":"T46-1","name":"Linear solve","domain":"Algebra","mastery":49,"attempts":6,"band":"weak"},
      {"code":"T46-2","name":"Systems","domain":"Algebra","mastery":50,"attempts":6,"band":"building"},
      {"code":"T46-3","name":"Angles","domain":"Geometry","mastery":75,"attempts":5,"band":"strong"},
      {"code":"T46-5","name":"Thin skill","domain":"Geometry","mastery":80,"attempts":4,"band":"thin"}]'::jsonb,
    'weak', jsonb_build_array(jsonb_build_object('code','T46-1','name','Linear solve','mastery',49,
      'topic_id',pg_temp.id(5),'topic_title','Linear equations')),
    'trend', '[]'::jsonb,
    'topics', jsonb_build_array(
      jsonb_build_object('topic_id',pg_temp.id(5),'title','Linear equations','unit_title','Unit One','solved',1,'total',4,'level','weak'),
      jsonb_build_object('topic_id',pg_temp.id(6),'title','Geometry','unit_title','Unit One','solved',1,'total',3,'level','strong'))),
  'ANL-01: shape_keys_exact (full fixture payload, nested keys and ordering)');

select is((select v -> 'summary' from ctx where k = 'a'),
  '{"solved":2,"total":7,"graded_answers":5}'::jsonb,
  'ANL-01: solved_counts_distinct_correct (distinct correct questions of this course, drafts and course B excluded)');

select is((select array_agg(s ->> 'code' order by s ->> 'code') from ctx, jsonb_array_elements(v -> 'skills') s where k = 'a'),
  array['T46-1', 'T46-2', 'T46-3', 'T46-5'], 'ANL-01: other_course_excluded (skills of course B never appear)');
select is((select v -> 'topics' from ctx where k = 'a'),
  jsonb_build_array(
    jsonb_build_object('topic_id', pg_temp.id(5), 'title', 'Linear equations', 'unit_title', 'Unit One', 'solved', 1, 'total', 4, 'level', 'weak'),
    jsonb_build_object('topic_id', pg_temp.id(6), 'title', 'Geometry', 'unit_title', 'Unit One', 'solved', 1, 'total', 3, 'level', 'strong')),
  'ANL-01: other_course_excluded (topics of course A only) with solved, total and level');

-- Thresholds are settings, rather than constants matching the defaults.
select tests.clear_authentication();
reset role;
update public.settings set value = '40' where key = 'mastery_weak_below';
update public.settings set value = '80' where key = 'pass_mark';
update public.settings set value = '7' where key = 'mastery_min_attempts';
select tests.authenticate_as('get_a');
select is((select jsonb_object_agg(s ->> 'code', s ->> 'band')
  from jsonb_array_elements(public.get_my_skills(pg_temp.id(1)) -> 'skills') s),
  '{"T46-1":"thin","T46-2":"thin","T46-3":"thin","T46-5":"thin"}'::jsonb,
  'ANL-01: bands_from_settings (changed minimum attempts)');
select tests.clear_authentication();
reset role;
update public.settings set value = '5' where key = 'mastery_min_attempts';
select tests.authenticate_as('get_a');
select is((select jsonb_object_agg(s ->> 'code', s ->> 'band')
  from jsonb_array_elements(public.get_my_skills(pg_temp.id(1)) -> 'skills') s),
  '{"T46-1":"building","T46-2":"building","T46-3":"building","T46-5":"thin"}'::jsonb,
  'ANL-01: bands_from_settings (changed weak and strong thresholds)');

-- Taxonomy not loaded: no tags at all.
select tests.clear_authentication();
reset role;
delete from public.question_skills;
select tests.authenticate_as('get_a');
insert into ctx values ('untagged', public.get_my_skills(pg_temp.id(1)));
select tests.clear_authentication();
reset role;
select is((select jsonb_build_object('summary', v -> 'summary', 'skills', v -> 'skills', 'weak', v -> 'weak', 'trend', v -> 'trend',
    'levels', (select jsonb_agg(t ->> 'level') from jsonb_array_elements(v -> 'topics') t))
  from ctx where k = 'untagged'),
  '{"summary":{"solved":2,"total":7,"graded_answers":5},"skills":[],"weak":[],"trend":[],"levels":["thin","thin"]}'::jsonb,
  'ANL-01: no_tags_summary_only (summary and topics still work, skills empty, topic levels thin)');

select is(has_function_privilege('anon', 'public.get_my_skills(uuid)', 'execute'), false,
  'ANL-01: anon cannot execute get_my_skills');
select is(has_function_privilege('authenticated', 'public.get_my_skills(uuid)', 'execute'), true,
  'ANL-01: grants_authenticated_only (authenticated can execute get_my_skills)');

select * from finish();
rollback;
