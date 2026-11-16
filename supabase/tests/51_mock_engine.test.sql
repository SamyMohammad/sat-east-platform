-- MCK-01 Task 1: mock settings, scale tables, estimate, mock_runs, unlock, hub. From supabase/templates/test.sql.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into public.courses (code, title, slug) values ('SAT', 'Mock SAT', 'mock-sat')
on conflict (code) do nothing;

create function pg_temp.sc(p_key text) returns jsonb language sql stable as
  $$ select value from public.settings where key = p_key $$;

-- Settings and teacher spec ----------------------------------------------------------------------
select results_eq($$ select key, value from public.settings
    where key in ('mock_unlock_first_topics', 'mock_unlock_step_topics', 'mock_gap_s', 'mock_warn_s', 'mock_score_margin')
    order by key $$,
  $$ values ('mock_gap_s', '120'::jsonb), ('mock_score_margin', '30'::jsonb), ('mock_unlock_first_topics', '3'::jsonb),
            ('mock_unlock_step_topics', '3'::jsonb), ('mock_warn_s', '300'::jsonb) $$,
  'MCK-01: mock settings exist with their defaults');
select results_eq($$ select key, grp, min, max from private.teacher_setting_spec() where grp = 'Mock' order by sort $$,
  $$ values ('mock_unlock_first_topics', 'Mock', 0, 50), ('mock_unlock_step_topics', 'Mock', 0, 50),
            ('mock_gap_s', 'Mock', 0, 900), ('mock_warn_s', 'Mock', 0, 1800), ('mock_score_margin', 'Mock', 0, 100) $$,
  'MCK-01: mock settings are in the teacher spec with their ranges');
select is((select count(*)::int from private.teacher_setting_spec() where key like 'sat\_scale%'), 0,
  'MCK-01: scale tables are not teacher-editable');

-- Scale tables ---------------------------------------------------------------------------------------
select is(jsonb_array_length(pg_temp.sc('sat_scale_hard')), 45, 'MCK-01: hard scale has 45 entries');
select is(jsonb_array_length(pg_temp.sc('sat_scale_easy')), 45, 'MCK-01: easy scale has 45 entries');
select ok(private.mock_scale_ok(pg_temp.sc('sat_scale_hard')), 'MCK-01: seeded hard scale is valid');
select ok(private.mock_scale_ok(pg_temp.sc('sat_scale_easy')), 'MCK-01: seeded easy scale is valid');
select is(pg_temp.sc('sat_scale_hard') -> 44, '800'::jsonb, 'MCK-01: hard scale tops out at 800');
select is(pg_temp.sc('sat_scale_easy') -> 44, '620'::jsonb, 'MCK-01: easy scale tops out at 620');
select is(pg_temp.sc('sat_scale_hard') -> 0, '200'::jsonb, 'MCK-01: hard scale starts at 200');
select is(pg_temp.sc('sat_scale_easy') -> 0, '200'::jsonb, 'MCK-01: easy scale starts at 200');
select is(private.mock_scale_ok(pg_temp.sc('sat_scale_hard') - 44), false, 'MCK-01: 44 entries are rejected');
select is(private.mock_scale_ok(pg_temp.sc('sat_scale_hard') || '800'::jsonb), false, 'MCK-01: 46 entries are rejected');
select is(private.mock_scale_ok(jsonb_set(pg_temp.sc('sat_scale_hard'), '{0}', '190')), false, 'MCK-01: a value of 190 is rejected');
select is(private.mock_scale_ok(jsonb_set(pg_temp.sc('sat_scale_hard'), '{44}', '805')), false, 'MCK-01: a value of 805 is rejected');
select is(private.mock_scale_ok(jsonb_set(pg_temp.sc('sat_scale_hard'), '{1}', '215')), false, 'MCK-01: a non-multiple of 10 is rejected');
select is(private.mock_scale_ok(jsonb_set(pg_temp.sc('sat_scale_hard'), '{10}', '300')), false, 'MCK-01: a decreasing pair is rejected');
select is(private.mock_scale_ok(jsonb_set(pg_temp.sc('sat_scale_hard'), '{5}', '"270"')), false, 'MCK-01: a string entry is rejected');
select is(private.mock_scale_ok('{}'::jsonb), false, 'MCK-01: an object is rejected');
select is(private.mock_scale_ok('null'::jsonb), false, 'MCK-01: json null is rejected');
select is(private.mock_scale_ok(null), false, 'MCK-01: sql null is rejected');

-- Estimate -------------------------------------------------------------------------------------------
select results_eq($$ select * from private.mock_estimate('M2H', 44) $$, $$ values (770, 800) $$, 'MCK-01: M2H 44 is 770-800');
select results_eq($$ select * from private.mock_estimate('M2E', 44) $$, $$ values (590, 650) $$, 'MCK-01: M2E 44 is 590-650');
select results_eq($$ select * from private.mock_estimate('M2H', 0) $$, $$ values (200, 230) $$, 'MCK-01: M2H 0 clamps low to 200');
select results_eq($$ select * from private.mock_estimate('M2E', 22) $$, $$ values (380, 440) $$,
  'MCK-01: M2E 22 is the easy-table value 410 plus or minus the margin');
select throws_ok($$ select * from private.mock_estimate('M3', 10) $$, 'P0001', 'internal', 'MCK-01: bad route is internal');
select throws_ok($$ select * from private.mock_estimate(null, 10) $$, 'P0001', 'internal', 'MCK-01: null route is internal');
select throws_ok($$ select * from private.mock_estimate('M2H', 45) $$, 'P0001', 'internal', 'MCK-01: raw 45 is internal');
select throws_ok($$ select * from private.mock_estimate('M2H', -1) $$, 'P0001', 'internal', 'MCK-01: raw -1 is internal');
select throws_ok($$ select * from private.mock_estimate('M2H', null) $$, 'P0001', 'internal', 'MCK-01: null raw is internal');
update public.settings set value = (value - 44) where key = 'sat_scale_hard';
select throws_ok($$ select * from private.mock_estimate('M2H', 10) $$, 'P0001', 'internal', 'MCK-01: an invalid scale table is internal');
select lives_ok($$ select * from private.mock_estimate('M2E', 10) $$, 'MCK-01: the other route still works');
update public.settings set value = '"x"'::jsonb where key = 'sat_scale_hard';
select throws_ok($$ select * from private.mock_estimate('M2H', 10) $$, 'P0001', 'internal', 'MCK-01: a non-array scale is internal');
update public.settings set value = '10'::jsonb where key = 'mock_score_margin';
select results_eq($$ select * from private.mock_estimate('M2E', 44) $$, $$ values (610, 630) $$, 'MCK-01: the margin is read from settings');

-- mock_runs ----------------------------------------------------------------------------------------
select ok((select relrowsecurity from pg_class where oid = 'private.mock_runs'::regclass), 'MCK-01: mock_runs has RLS enabled');
select is((select count(*)::int from pg_policies where schemaname = 'private' and tablename = 'mock_runs'), 0,
  'MCK-01: mock_runs has no policy');
select ok(not has_table_privilege('authenticated', 'private.mock_runs', 'select')
  and not has_table_privilege('anon', 'private.mock_runs', 'select')
  and not has_table_privilege('authenticated', 'private.mock_runs', 'insert'),
  'MCK-01: API roles have no grants on mock_runs');
select ok(exists (select 1 from pg_indexes where schemaname = 'private' and tablename = 'mock_runs'
  and indexdef like '%(user_id)%' and indexdef like '%finished_at IS NULL%'), 'MCK-01: partial index on unfinished runs');
select ok(not has_function_privilege('authenticated', 'private.mock_scale_ok(jsonb)', 'execute')
  and not has_function_privilege('authenticated', 'private.mock_estimate(text,integer)', 'execute')
  and not has_function_privilege('authenticated', 'private.mock_form_unlock(uuid,uuid)', 'execute')
  and not has_function_privilege('anon', 'private.mock_form_unlock(uuid,uuid)', 'execute'),
  'MCK-01: private helpers are not executable by API roles');

-- Fixture --------------------------------------------------------------------------------------------
select tests.create_supabase_user('mk1_student');
select tests.create_supabase_user('mk1_other');
select tests.create_supabase_user('mk1_noenrol');
create temp table t_ids as select
  (select id from public.courses where code = 'SAT') as course_id,
  tests.get_supabase_uid('mk1_student') as uid,
  tests.get_supabase_uid('mk1_other') as other_uid,
  private.mock_template_for((select id from public.courses where code = 'SAT')) as tpl;
grant select on t_ids to authenticated;

insert into public.topics (course_id, title, slug, sort, is_published)
select (select course_id from t_ids), 'MK1 topic ' || g, 'mk1-topic-' || g, g, true from generate_series(1, 8) g;

insert into public.enrollments (user_id, course_id, status, expires_at, mock_set_no)
select uid, course_id, 'active', now() + interval '30 days', 1 from t_ids;
insert into public.enrollments (user_id, course_id, status, expires_at, mock_set_no)
select other_uid, course_id, 'active', now() + interval '30 days', 2 from t_ids;

-- set 1: forms 1 and 3 published, 2 draft, 4 has only two published modules. set 2: form 1 published.
insert into public.mock_forms (template_id, set_no, form_no, module, question_ids, status, published_at)
select t.tpl, f.set_no, f.form_no, m.module, '{}', f.status, case when f.status = 'published' then now() end
from t_ids t,
     (values (1, 1, 'published'), (1, 2, 'draft'), (1, 3, 'published'), (2, 1, 'published')) f(set_no, form_no, status),
     (values ('M1'), ('M2E'), ('M2H')) m(module);
insert into public.mock_forms (template_id, set_no, form_no, module, question_ids, status, published_at)
select t.tpl, 1, 4, m.module, '{}', case when m.module = 'M2H' then 'draft' else 'published' end, now()
from t_ids t, (values ('M1'), ('M2E'), ('M2H')) m(module);

create function pg_temp.pass(p_n int) returns void language sql as $$
  delete from public.topic_progress where user_id = (select uid from t_ids);
  insert into public.topic_progress (user_id, topic_id, quiz_passed_at)
  select (select uid from t_ids), id, now()
  from (select id from public.topics where slug like 'mk1-topic-%' order by sort limit p_n) x;
$$;

-- mock_form_unlock -----------------------------------------------------------------------------------
select results_eq($$ select form_no, k, topics_needed from private.mock_form_unlock((select uid from t_ids), (select course_id from t_ids)) order by form_no $$,
  $$ values (1, 1, 3), (3, 2, 6) $$, 'MCK-01: unlock lists published forms of the set with rank and topics needed');
select results_eq($$ select form_no, k, topics_needed from private.mock_form_unlock((select other_uid from t_ids), (select course_id from t_ids)) $$,
  $$ values (1, 1, 3) $$, 'MCK-01: unlock only sees the student''s own set');
select is((select count(*)::int from private.mock_form_unlock((select uid from t_ids), (select course_id from t_ids)) where form_no in (2, 4)), 0,
  'MCK-01: drafts and partly published forms are not listed');
update public.settings set value = '2'::jsonb where key = 'mock_unlock_first_topics';
update public.settings set value = '5'::jsonb where key = 'mock_unlock_step_topics';
select results_eq($$ select topics_needed from private.mock_form_unlock((select uid from t_ids), (select course_id from t_ids)) order by form_no $$,
  $$ values (2), (7) $$, 'MCK-01: unlock follows first + (k-1) * step from settings');
update public.settings set value = '3'::jsonb where key in ('mock_unlock_first_topics', 'mock_unlock_step_topics');
select is((select count(*)::int from private.mock_form_unlock((select uid from t_ids), gen_random_uuid())), 0,
  'MCK-01: no enrolment for the course lists nothing');

-- get_mock_hub -----------------------------------------------------------------------------------------
create function pg_temp.hub() returns jsonb language sql as $$ select public.get_mock_hub((select course_id from t_ids)) $$;
create function pg_temp.states() returns text language sql as $$
  select string_agg((f ->> 'form_no') || ':' || (f ->> 'state') || ':' || (f ->> 'topics_needed'), ',' order by (f ->> 'form_no')::int)
  from jsonb_array_elements(pg_temp.hub() -> 'forms') f $$;

grant execute on function pg_temp.hub() to authenticated;
grant execute on function pg_temp.states() to authenticated;
select pg_temp.pass(0);
select tests.authenticate_as('mk1_student');
select is(pg_temp.hub() -> 'set_no', '1'::jsonb, 'MCK-01: hub reports the enrolment set');
select is(pg_temp.hub() -> 'topics_passed', '0'::jsonb, 'MCK-01: hub reports 0 passed topics');
select is(pg_temp.states(), '1:locked:3,3:locked:6', 'MCK-01: 0 passed -> both forms locked');
select is(jsonb_array_length(pg_temp.hub() -> 'forms'), 2, 'MCK-01: only published forms of the set appear');
select tests.clear_authentication();
reset role;
select pg_temp.pass(3);
select tests.authenticate_as('mk1_student');
select is(pg_temp.states(), '1:available:3,3:locked:6', 'MCK-01: 3 passed -> form 1 available');
select is(pg_temp.hub() -> 'topics_passed', '3'::jsonb, 'MCK-01: hub reports 3 passed topics');
select tests.clear_authentication();
reset role;
select pg_temp.pass(6);
select tests.authenticate_as('mk1_student');
select is(pg_temp.states(), '1:available:3,3:locked:6', 'MCK-01: 6 passed -> only the lowest form is available');
select is(pg_temp.hub() #> '{forms,0}', '{"form_no":1,"state":"available","topics_needed":3,"group_id":null,"est_low":null,"est_high":null}'::jsonb,
  'MCK-01: a not-started form has null group and estimate');

-- in_progress and finished (rows made as postgres: nothing creates runs yet).
select tests.clear_authentication();
reset role;
insert into private.mock_runs (group_id, user_id, course_id, template_id, set_no, form_no)
select '51000000-0000-0000-0000-000000000001', uid, course_id, tpl, 1, 1 from t_ids;
select tests.authenticate_as('mk1_student');
select is(pg_temp.states(), '1:in_progress:3,3:locked:6', 'MCK-01: unfinished run -> in_progress, nothing else available');
select is(pg_temp.hub() #>> '{forms,0,group_id}', '51000000-0000-0000-0000-000000000001', 'MCK-01: in_progress carries the group id');
select is(pg_temp.hub() #> '{forms,0,est_low}', 'null'::jsonb, 'MCK-01: in_progress has no estimate');
select tests.clear_authentication();
reset role;
update private.mock_runs set finished_at = now() where group_id = '51000000-0000-0000-0000-000000000001';
insert into public.mock_results (user_id, template_id, group_id, route, raw_m1, raw_m2, est_low, est_high)
select uid, tpl, '51000000-0000-0000-0000-000000000001', 'M2H', 15, 12, 640, 700 from t_ids;
select tests.authenticate_as('mk1_student');
select is(pg_temp.states(), '1:finished:3,3:available:6', 'MCK-01: finished form, next form available when unlocked');
select is(pg_temp.hub() #> '{forms,0}', '{"form_no":1,"state":"finished","topics_needed":3,"group_id":"51000000-0000-0000-0000-000000000001","est_low":640,"est_high":700}'::jsonb,
  'MCK-01: finished form carries group id and estimate');
select tests.clear_authentication();
reset role;
select pg_temp.pass(3);
select tests.authenticate_as('mk1_student');
select is(pg_temp.states(), '1:finished:3,3:locked:6', 'MCK-01: next form stays locked below its threshold');
-- a run of another set for the same form number does not count
select tests.clear_authentication();
reset role;
update private.mock_runs set set_no = 2 where group_id = '51000000-0000-0000-0000-000000000001';
select tests.authenticate_as('mk1_student');
select is(pg_temp.states(), '1:available:3,3:locked:6', 'MCK-01: runs of another set are ignored');
select tests.clear_authentication();
reset role;
update private.mock_runs set set_no = 1 where group_id = '51000000-0000-0000-0000-000000000001';

-- a changed set shows the new set
update public.enrollments set mock_set_no = 2 where user_id = (select uid from t_ids);
select tests.authenticate_as('mk1_student');
select is(pg_temp.hub() -> 'set_no', '2'::jsonb, 'MCK-01: hub follows a changed set');
select is(jsonb_array_length(pg_temp.hub() -> 'forms'), 1, 'MCK-01: new set lists its own forms');
select tests.clear_authentication();
reset role;
update public.enrollments set mock_set_no = 1 where user_id = (select uid from t_ids);

-- errors
select tests.authenticate_as('mk1_noenrol');
select throws_ok($$ select public.get_mock_hub((select course_id from t_ids)) $$, 'P0001', 'not_enrolled', 'MCK-01: no enrolment is not_enrolled');
select tests.authenticate_as('mk1_student');
select throws_ok($$ select public.get_mock_hub(null) $$, 'P0001', 'invalid_input', 'MCK-01: null course is invalid_input');
select throws_ok($$ select public.get_mock_hub(gen_random_uuid()) $$, 'P0001', 'not_enrolled', 'MCK-01: unknown course is not_enrolled');
select tests.clear_authentication();
reset role;
update public.enrollments set expires_at = now() - interval '1 day' where user_id = (select uid from t_ids);
select tests.authenticate_as('mk1_student');
select throws_ok($$ select public.get_mock_hub((select course_id from t_ids)) $$, 'P0001', 'access_expired', 'MCK-01: expired enrolment is access_expired');
select tests.clear_authentication();
reset role;
update public.enrollments set expires_at = now() + interval '30 days' where user_id = (select uid from t_ids);

-- permissions
set local role anon;
select throws_ok($$ select public.get_mock_hub(null) $$, '42501', null, 'MCK-01: anon cannot execute get_mock_hub');
reset role;
set local role authenticated;
select throws_ok($$ select public.get_mock_hub(null) $$, 'P0001', 'not_authenticated', 'MCK-01: no uid is not_authenticated');
select throws_ok($$ select count(*) from private.mock_runs $$, '42501', null, 'MCK-01: authenticated cannot read private.mock_runs');
reset role;

-- ================================================================================================
-- Task 2: start_mock, get_mock_stage, save_answer (mock_module), has_active_exam, hub resume.
-- ================================================================================================
update public.settings set value = '1000'::jsonb where key in ('rate_start_per_min', 'rate_save_per_min');
select tests.create_supabase_user('mk2_a');
select tests.create_supabase_user('mk2_b');
select tests.create_supabase_user('mk2_c');
select tests.create_supabase_user('mk2_d');
select tests.create_supabase_user('mk2_e');

insert into public.topics (course_id, title, slug, sort, is_published)
select (select course_id from t_ids), 'MK2 topic ' || g, 'mk2-topic-' || g, 100 + g, true from generate_series(1, 12) g;
insert into public.subtopics (id, topic_id, title, sort)
select '52000000-0000-0000-0000-000000000001', id, 'MK2 sub', 1 from public.topics where slug = 'mk1-topic-1';

-- 66 mock questions; n 1..66. Question 1 has choices and a key + explanation (must never leak).
create temp table t_q as
  select n, gen_random_uuid() as id from generate_series(1, 66) n;
insert into public.questions (id, topic_id, subtopic_id, type, difficulty, stem_md, pool, status, external_ref)
select q.id, (select id from public.topics where slug = 'mk1-topic-1'), '52000000-0000-0000-0000-000000000001',
       case when q.n % 4 = 0 then 'spr' else 'mcq' end::public.question_type, 'M', 'Stem ' || q.n, 'mock_reserve', 'published', 'MK52-' || q.n
from t_q q;
insert into public.question_choices (question_id, label, body_md)
select q.id, l, 'Choice ' || l from t_q q, (values ('A'), ('B'), ('C'), ('D')) c(l) where q.n % 4 <> 0;
insert into private.question_keys (question_id, correct_answer, explanation_md)
select q.id, '{"choice":"B"}', 'SECRET explanation ' || q.n from t_q q;

-- set 3: forms 1 and 2 ok, form 3 published but its M1 has 21 questions, form 4 draft.
create function pg_temp.ids(p_from int, p_to int, p_desc boolean) returns uuid[] language sql as $$
  select array_agg(id order by case when p_desc then -n else n end) from t_q where n between p_from and p_to $$;
insert into public.mock_forms (template_id, set_no, form_no, module, question_ids, status, published_at)
select (select tpl from t_ids), 3, f.form_no, m.module,
       case m.module when 'M1' then pg_temp.ids(1, case when f.form_no = 3 then 21 else 22 end, true)
                     when 'M2E' then pg_temp.ids(23, 44, false) else pg_temp.ids(45, 66, false) end,
       f.status, now()
from (values (1, 'published'), (2, 'published'), (3, 'published'), (4, 'draft')) f(form_no, status),
     (values ('M1'), ('M2E'), ('M2H')) m(module);

create function pg_temp.setup(p_user text, p_passed int) returns void language sql as $$
  insert into public.enrollments (user_id, course_id, status, expires_at, mock_set_no)
  select tests.get_supabase_uid(p_user), course_id, 'active', now() + interval '30 days', 3 from t_ids;
  insert into public.topic_progress (user_id, topic_id, quiz_passed_at)
  select tests.get_supabase_uid(p_user), id, now()
  from (select id from public.topics where slug like 'mk2-topic-%' order by sort limit p_passed) x;
$$;
select pg_temp.setup('mk2_a', 3);
select pg_temp.setup('mk2_b', 0);
select pg_temp.setup('mk2_c', 6);
select pg_temp.setup('mk2_d', 3);
select pg_temp.setup('mk2_e', 9);
update public.enrollments set expires_at = now() - interval '1 day' where user_id = tests.get_supabase_uid('mk2_d');

create temp table t_st (label text, r jsonb);
grant all on t_st to authenticated;
create function pg_temp.st(p_label text) returns jsonb language sql stable as $$ select r from t_st where label = p_label $$;

-- start ------------------------------------------------------------------------------------------
select tests.authenticate_as('mk2_a');
insert into t_st select 'a1', public.start_mock((select course_id from t_ids), 1);
select tests.clear_authentication();
reset role;
select is(pg_temp.st('a1') ->> 'stage', 'module', 'MCK-01: start_mock returns a module stage');
select is(pg_temp.st('a1') -> 'module_no', '1'::jsonb, 'MCK-01: first stage is module 1');
select is(jsonb_array_length(pg_temp.st('a1') -> 'questions'), 22, 'MCK-01: module 1 has 22 questions');
select is((select array_agg(q ->> 'id' order by ord) from jsonb_array_elements(pg_temp.st('a1') -> 'questions') with ordinality x(q, ord)),
  (select array_agg(id::text order by n desc) from t_q where n <= 22), 'MCK-01: questions follow the form''s M1 slot order');
select is(pg_temp.st('a1') -> 'time_limit_s', '2100'::jsonb, 'MCK-01: time limit is the blueprint M1 time');
select is(pg_temp.st('a1') -> 'warn_s', '300'::jsonb, 'MCK-01: warn_s comes from mock_warn_s');
select is(pg_temp.st('a1') -> 'title', '"Module 1"'::jsonb, 'MCK-01: title is Module 1');
select is((pg_temp.st('a1') ->> 'deadline')::timestamptz,
  (select started_at + interval '2100 seconds' from public.attempts where id = (pg_temp.st('a1') ->> 'attempt_id')::uuid),
  'MCK-01: deadline is started_at + time_limit_s');
select ok(pg_temp.st('a1') ->> 'server_now' is not null and pg_temp.st('a1') -> 'client_seq' = '0'::jsonb
  and pg_temp.st('a1') -> 'answers' = '[]'::jsonb, 'MCK-01: fresh stage has server_now, no answers, client_seq 0');
select is((pg_temp.st('a1') -> 'questions' -> 21) ->> 'id', (select id::text from t_q where n = 1), 'MCK-01: last slot is the last id');
select is(jsonb_array_length((select q -> 'choices' from jsonb_array_elements(pg_temp.st('a1') -> 'questions') q
  where q ->> 'id' = (select id::text from t_q where n = 1))), 4, 'MCK-01: mcq carries its choices');
select ok(pg_temp.st('a1')::text !~ '(correct_answer|explanation|is_correct|"key"|SECRET|misconception)',
  'MCK-01: the stage payload has no key, explanation or is_correct');
select is((select count(*)::int from private.mock_runs where user_id = tests.get_supabase_uid('mk2_a')), 1, 'MCK-01: one run row');
select is((select m1_attempt_id from private.mock_runs where user_id = tests.get_supabase_uid('mk2_a')),
  (pg_temp.st('a1') ->> 'attempt_id')::uuid, 'MCK-01: run points at the module 1 attempt');
select is((select group_id from private.mock_runs where user_id = tests.get_supabase_uid('mk2_a')),
  (pg_temp.st('a1') ->> 'group_id')::uuid, 'MCK-01: stage group id is the run id');
select results_eq($$ select kind::text, module_no, mock_attempt_group, mock_form_id, status::text, time_limit_s, course_id
    from public.attempts where id = (pg_temp.st('a1') ->> 'attempt_id')::uuid $$,
  $$ select 'mock_module', 1, (pg_temp.st('a1') ->> 'group_id')::uuid,
            (select id from public.mock_forms where set_no = 3 and form_no = 1 and module = 'M1'),
            'in_progress', 2100, (select course_id from t_ids) $$,
  'MCK-01: attempt row is a mock_module of module 1 on the M1 form row');
select is((select array_agg(question_id order by position) from public.attempt_questions
  where attempt_id = (pg_temp.st('a1') ->> 'attempt_id')::uuid),
  (select question_ids from public.mock_forms where set_no = 3 and form_no = 1 and module = 'M1'),
  'MCK-01: attempt_questions are in slot order');

select tests.authenticate_as('mk2_a');
insert into t_st select 'a2', public.start_mock((select course_id from t_ids), 1);
select tests.clear_authentication();
reset role;
select is(pg_temp.st('a2') ->> 'attempt_id', pg_temp.st('a1') ->> 'attempt_id', 'MCK-01: second start_mock returns the same attempt');
select is((select count(*)::int from private.mock_runs where user_id = tests.get_supabase_uid('mk2_a')), 1, 'MCK-01: still one run');
select is((select count(*)::int from public.attempts where user_id = tests.get_supabase_uid('mk2_a')), 1, 'MCK-01: still one attempt');

-- guards -------------------------------------------------------------------------------------------
select tests.authenticate_as('mk2_b');
select throws_ok($$ select public.start_mock((select course_id from t_ids), 1) $$, 'P0001', 'mock_locked', 'MCK-01: too few topics is mock_locked');
select tests.authenticate_as('mk2_c');
select throws_ok($$ select public.start_mock((select course_id from t_ids), 2) $$, 'P0001', 'mock_locked',
  'MCK-01: form 2 before form 1 is mock_locked even with enough topics');
select tests.authenticate_as('mk2_a');
select throws_ok($$ select public.start_mock((select course_id from t_ids), 2) $$, 'P0001', 'mock_in_progress',
  'MCK-01: another form while a run is unfinished is mock_in_progress');
select tests.authenticate_as('mk2_d');
select throws_ok($$ select public.start_mock((select course_id from t_ids), 1) $$, 'P0001', 'access_expired', 'MCK-01: expired enrolment is access_expired');
select tests.authenticate_as('mk1_noenrol');
select throws_ok($$ select public.start_mock((select course_id from t_ids), 1) $$, 'P0001', 'not_enrolled', 'MCK-01: no enrolment is not_enrolled');
select tests.authenticate_as('mk2_c');
select throws_ok($$ select public.start_mock((select course_id from t_ids), 99) $$, 'P0001', 'invalid_input', 'MCK-01: unknown form is invalid_input');
select throws_ok($$ select public.start_mock((select course_id from t_ids), 4) $$, 'P0001', 'invalid_input', 'MCK-01: draft form is invalid_input');
select throws_ok($$ select public.start_mock((select course_id from t_ids), null) $$, 'P0001', 'invalid_input', 'MCK-01: null form is invalid_input');
select throws_ok($$ select public.start_mock(null, 1) $$, 'P0001', 'invalid_input', 'MCK-01: null course is invalid_input');
select tests.clear_authentication();
reset role;

-- finished form is mock_already_taken; a form whose M1 has 21 questions is internal and leaves nothing.
insert into private.mock_runs (user_id, course_id, template_id, set_no, form_no, finished_at)
select tests.get_supabase_uid('mk2_e'), course_id, tpl, 3, f, now() from t_ids, generate_series(1, 2) f;
select tests.authenticate_as('mk2_e');
select throws_ok($$ select public.start_mock((select course_id from t_ids), 1) $$, 'P0001', 'mock_already_taken', 'MCK-01: finished form is mock_already_taken');
select throws_ok($$ select public.start_mock((select course_id from t_ids), 3) $$, 'P0001', 'internal', 'MCK-01: a 21-question module is internal');
select tests.clear_authentication();
reset role;
select is((select count(*)::int from private.mock_runs where user_id = tests.get_supabase_uid('mk2_e') and form_no = 3), 0, 'MCK-01: a failed start leaves no run');
select is((select count(*)::int from public.attempts where user_id = tests.get_supabase_uid('mk2_e')), 0, 'MCK-01: a failed start leaves no attempt');

-- save_answer ----------------------------------------------------------------------------------------
grant select on t_q to authenticated;
create function pg_temp.q1() returns uuid language sql stable as $$ select id from t_q where n = 1 $$;
create function pg_temp.att() returns uuid language sql stable as $$ select (r ->> 'attempt_id')::uuid from t_st where label = 'a1' $$;
grant execute on function pg_temp.q1() to authenticated;
grant execute on function pg_temp.att() to authenticated;
grant execute on function pg_temp.st(text) to authenticated;
select tests.authenticate_as('mk2_a');
select is(public.save_answer(pg_temp.att(), pg_temp.q1(), 'B', 1500, true, array['A'], 1), '{"ok":true}'::jsonb, 'MCK-01: save_answer works on a mock module');
select tests.clear_authentication();
reset role;
select results_eq($$ select answer, marked_for_review, eliminated, client_seq from public.attempt_answers where attempt_id = pg_temp.att() $$,
  $$ values ('{"value":"B"}'::jsonb, true, '["A"]'::jsonb, 1) $$, 'MCK-01: answer, mark and eliminated are stored');
select tests.authenticate_as('mk2_a');
select is(public.save_answer(pg_temp.att(), pg_temp.q1(), 'C', 1500, false, array[]::text[], 1), '{"ok":true,"stale":true}'::jsonb,
  'MCK-01: a stale client_seq is ignored');
select is(public.save_answer(pg_temp.att(), pg_temp.q1(), 'C', 1500, false, array[]::text[], 2) ->> 'ok', 'true', 'MCK-01: a newer client_seq is stored');
select throws_ok($$ select public.save_answer(pg_temp.att(), gen_random_uuid(), 'A', 1, false, array[]::text[], 3) $$, 'P0001', 'invalid_input',
  'MCK-01: a question outside the module is invalid_input');
select tests.authenticate_as('mk2_b');
select throws_ok($$ select public.save_answer(pg_temp.att(), pg_temp.q1(), 'A', 1, false, array[]::text[], 9) $$, 'P0001', 'invalid_input',
  'MCK-01: another student''s mock attempt is refused');
select tests.clear_authentication();
reset role;

-- get_mock_stage, has_active_exam, expiry of enrolment mid-run ------------------------------------------
select tests.authenticate_as('mk2_a');
insert into t_st select 'a3', public.get_mock_stage((pg_temp.st('a1') ->> 'group_id')::uuid);
select tests.clear_authentication();
reset role;
select is(pg_temp.st('a3') ->> 'attempt_id', pg_temp.st('a1') ->> 'attempt_id', 'MCK-01: get_mock_stage resumes the same module');
select is(pg_temp.st('a3') -> 'answers', jsonb_build_array(jsonb_build_object('question_id', (select id from t_q where n = 1), 'answer', 'C', 'marked', false, 'eliminated', jsonb_build_array())),
  'MCK-01: resume carries saved answers with eliminated');
select is(pg_temp.st('a3') -> 'client_seq', '2'::jsonb, 'MCK-01: resume carries the latest client_seq');
select ok((pg_temp.st('a3') ->> 'server_now')::timestamptz >= (pg_temp.st('a1') ->> 'server_now')::timestamptz, 'MCK-01: server_now does not go back');
select ok(pg_temp.st('a3')::text !~ '(correct_answer|explanation|is_correct|"key"|SECRET)', 'MCK-01: resume payload has no key either');
select tests.authenticate_as('mk2_b');
select throws_ok($$ select public.get_mock_stage((select (r ->> 'group_id')::uuid from t_st where label = 'a1')) $$, 'P0001', 'invalid_input',
  'MCK-01: another student''s group is invalid_input');
select throws_ok($$ select public.get_mock_stage(null) $$, 'P0001', 'invalid_input', 'MCK-01: null group is invalid_input');
select throws_ok($$ select public.get_mock_stage(gen_random_uuid()) $$, 'P0001', 'invalid_input', 'MCK-01: unknown group is invalid_input');
select tests.clear_authentication();
reset role;

select is(private.has_active_exam(tests.get_supabase_uid('mk2_a')), true, 'MCK-01: has_active_exam is true during a mock run');
select is(private.has_active_exam(tests.get_supabase_uid('mk2_b')), false, 'MCK-01: has_active_exam is false with nothing in progress');
insert into public.attempts (id, user_id, kind, course_id, topic_id, status, started_at, time_limit_s)
select '52000000-0000-0000-0000-0000000000a1', tests.get_supabase_uid('mk2_b'), 'quiz', course_id,
       (select id from public.topics where slug = 'mk1-topic-1'), 'in_progress', now(), 600 from t_ids;
select is(private.has_active_exam(tests.get_supabase_uid('mk2_b')), true, 'MCK-01: has_active_exam is true during a quiz');
update public.attempts set started_at = now() - interval '2 hours' where id = '52000000-0000-0000-0000-0000000000a1';
select is(private.has_active_exam(tests.get_supabase_uid('mk2_b')), false, 'MCK-01: an overdue quiz is not active');
update public.attempts set started_at = now(), status = 'submitted' where id = '52000000-0000-0000-0000-0000000000a1';
select is(private.has_active_exam(tests.get_supabase_uid('mk2_b')), false, 'MCK-01: a submitted quiz is not active');
select is(private.has_active_exam(tests.get_supabase_uid('mk2_e')), false, 'MCK-01: finished runs are not active');
select is(private.has_active_exam(null), false, 'MCK-01: has_active_exam of null is false');

-- deadline: grace is time_limit_s + save_grace_s
update public.attempts set started_at = now() - interval '2120 seconds' where id = pg_temp.att();
select tests.authenticate_as('mk2_a');
select is(public.save_answer(pg_temp.att(), pg_temp.q1(), 'D', 1, false, array[]::text[], 3) ->> 'ok', 'true',
  'MCK-01: a save inside time limit plus grace still works');
select tests.clear_authentication();
reset role;
update public.attempts set started_at = now() - interval '2140 seconds' where id = pg_temp.att();
select tests.authenticate_as('mk2_a');
select throws_ok($$ select public.save_answer(pg_temp.att(), pg_temp.q1(), 'D', 1, false, array[]::text[], 4) $$, 'P0001', 'deadline_passed',
  'MCK-01: a save after time limit plus grace is deadline_passed');
select tests.clear_authentication();
reset role;
update public.attempts set started_at = now() where id = pg_temp.att();

-- enrolment expires mid-run: save, resume and the hub still work (Decision 6)
update public.enrollments set expires_at = now() - interval '1 day' where user_id = tests.get_supabase_uid('mk2_a');
select tests.authenticate_as('mk2_a');
select is(public.save_answer(pg_temp.att(), pg_temp.q1(), 'A', 1, false, array[]::text[], 5) ->> 'ok', 'true', 'MCK-01: save works after the enrolment expired');
select is(public.get_mock_stage((pg_temp.st('a1') ->> 'group_id')::uuid) ->> 'stage', 'module', 'MCK-01: resume works after the enrolment expired');
select is(public.start_mock((select course_id from t_ids), 1) ->> 'attempt_id', pg_temp.st('a1') ->> 'attempt_id',
  'MCK-01: start_mock on the running form resumes after the enrolment expired');
select is(public.get_mock_hub((select course_id from t_ids)) #>> '{forms,0,state}', 'in_progress', 'MCK-01: hub shows the in-progress form after expiry');
select is(public.get_mock_hub((select course_id from t_ids)) #>> '{forms,0,group_id}', pg_temp.st('a1') ->> 'group_id', 'MCK-01: hub carries its group id after expiry');
select tests.clear_authentication();
reset role;

-- permissions
set local role anon;
select throws_ok($$ select public.start_mock(null, null) $$, '42501', null, 'MCK-01: anon cannot execute start_mock');
select throws_ok($$ select public.get_mock_stage(null) $$, '42501', null, 'MCK-01: anon cannot execute get_mock_stage');
reset role;
set local role authenticated;
select throws_ok($$ select public.start_mock(null, null) $$, 'P0001', 'not_authenticated', 'MCK-01: start_mock checks the uid');
select throws_ok($$ select public.get_mock_stage(null) $$, 'P0001', 'not_authenticated', 'MCK-01: get_mock_stage checks the uid');
reset role;
select ok(not has_function_privilege('authenticated', 'private.has_active_exam(uuid)', 'execute')
  and not has_function_privilege('anon', 'private.has_active_exam(uuid)', 'execute')
  and not has_function_privilege('authenticated', 'private.mock_stage(uuid)', 'execute')
  and not has_function_privilege('authenticated', 'private.mock_lock_user(uuid)', 'execute')
  and not has_function_privilege('authenticated', 'private.mock_access(uuid,uuid)', 'execute'),
  'MCK-01: task 2 helpers are not executable by API roles');


-- ================================================================================================
-- Task 3: submit, routing, gap, module 2, tick, results, leak guards, cron, active_run.
-- ================================================================================================
-- The Task 1 estimate tests broke the hard scale and the margin on purpose; restore both.
update public.settings set value = '[200,210,230,240,250,270,280,300,310,320,340,350,360,380,390,400,420,430,450,460,470,490,500,510,530,540,550,570,580,600,610,620,640,650,660,680,690,700,720,730,750,760,770,790,800]'::jsonb
where key = 'sat_scale_hard';
update public.settings set value = '30'::jsonb where key = 'mock_score_margin';
select tests.create_supabase_user('mk3_a');
select tests.create_supabase_user('mk3_b');
select tests.create_supabase_user('mk3_c');
select tests.create_supabase_user('mk3_d');
select tests.create_supabase_user('mk3_e');
select tests.create_supabase_user('mk3_f');
select pg_temp.setup('mk3_a', 3);
select pg_temp.setup('mk3_b', 3);
select pg_temp.setup('mk3_c', 3);
select pg_temp.setup('mk3_d', 3);
select pg_temp.setup('mk3_e', 3);
select pg_temp.setup('mk3_f', 3);

-- one skill on every mock question, so mastery moves exactly once per answer
insert into public.skills (code, name, domain) values ('TEST.MK3.SK', 'Mock Task 3 skill', 'Algebra');
insert into public.question_skills (question_id, skill_id)
select q.id, (select id from public.skills where code = 'TEST.MK3.SK') from t_q q;

-- Answers 'B' (the key of every mcq) for the first p_k mcq questions of a module, as postgres.
create function pg_temp.ans(p_att uuid, p_k int) returns void language sql as $$
  insert into public.attempt_answers (attempt_id, question_id, answer, time_ms, client_seq, answered_at)
  select aq.attempt_id, aq.question_id, '{"value":"B"}'::jsonb, 1000, 1, now()
  from public.attempt_questions aq join public.questions q on q.id = aq.question_id
  where aq.attempt_id = p_att and q.type = 'mcq' order by aq.position limit p_k $$;
create function pg_temp.att(p_label text) returns uuid language sql stable as $$ select (r ->> 'attempt_id')::uuid from t_st where label = p_label $$;
create function pg_temp.grp(p_label text) returns uuid language sql stable as $$ select (r ->> 'group_id')::uuid from t_st where label = p_label $$;
create function pg_temp.uid(p_user text) returns uuid language sql stable as $$ select tests.get_supabase_uid(p_user) $$;
grant execute on function pg_temp.att(text) to authenticated;
grant execute on function pg_temp.grp(text) to authenticated;

-- A: the happy path, routed hard ------------------------------------------------------------------------
select tests.authenticate_as('mk3_a');
insert into t_st select 'm3a1', public.start_mock((select course_id from t_ids), 1);
select tests.clear_authentication();
reset role;
create temp table t_est as select * from private.mock_estimate('M2H', 24);
grant select on t_est to authenticated;
select pg_temp.ans(pg_temp.att('m3a1'), 14);
select tests.authenticate_as('mk3_a');
insert into t_st select 'a_gap', public.submit_attempt(pg_temp.att('m3a1'));
select tests.clear_authentication();
reset role;
select is(pg_temp.st('a_gap') ->> 'stage', 'gap', 'MCK-01: submitting module 1 returns the gap stage');
select is((pg_temp.st('a_gap') ->> 'gap_ends_at')::timestamptz,
  (select m1_submitted_at + interval '120 seconds' from private.mock_runs where group_id = pg_temp.grp('m3a1')),
  'MCK-01: gap_ends_at is m1_submitted_at + mock_gap_s');
select ok(pg_temp.st('a_gap')::text !~ '(score|route|raw|M2H|M2E)', 'MCK-01: the gap stage shows no score or route');
select results_eq($$ select raw_m1, route from private.mock_runs where group_id = pg_temp.grp('m3a1') $$,
  $$ values (14, 'M2H') $$, 'MCK-01: 14 correct routes to M2H');
select ok((select status = 'submitted' and submitted_at is not null from public.attempts where id = pg_temp.att('m3a1')),
  'MCK-01: module 1 is submitted');

-- leak guards, as the student
select tests.authenticate_as('mk3_a');
select results_eq($$ select score_raw, score_total, score_pct, meta from public.attempts where id = pg_temp.att('m3a1') $$,
  $$ values (null::int, null::int, null::numeric, '{}'::jsonb) $$, 'MCK-01: module 1 attempt shows no score and no meta');
select is((select count(*)::int from public.attempt_answers where attempt_id = pg_temp.att('m3a1')), 0,
  'MCK-01: module 1 answers (is_correct) are hidden before the run finishes');
select throws_ok($$ select public.get_attempt_review(pg_temp.att('m3a1')) $$, 'P0001', 'invalid_input',
  'MCK-01: get_attempt_review refuses a mock module');
select is(public.submit_attempt(pg_temp.att('m3a1')), pg_temp.st('a_gap'), 'MCK-01: submitting module 1 twice returns the same stage');
select tests.clear_authentication();
reset role;
select results_eq($$ select raw_m1, route from private.mock_runs where group_id = pg_temp.grp('m3a1') $$,
  $$ values (14, 'M2H') $$, 'MCK-01: a second submit does not re-route or change raw_m1');
select is((select count(*)::int from public.attempt_answers where attempt_id = pg_temp.att('m3a1')), 22,
  'MCK-01: module 1 has 22 graded answer rows (unanswered counted wrong)');

-- module 2 during the gap
select tests.authenticate_as('mk3_a');
insert into t_st select 'm3a2', public.start_mock_module2(pg_temp.grp('m3a1'));
insert into t_st select 'm3a2b', public.start_mock_module2(pg_temp.grp('m3a1'));
select tests.clear_authentication();
reset role;
select is(pg_temp.st('m3a2') ->> 'stage', 'module', 'MCK-01: start_mock_module2 returns a module stage');
select is(pg_temp.st('m3a2') -> 'module_no', '2'::jsonb, 'MCK-01: it is module 2');
select is(pg_temp.st('m3a2') -> 'title', '"Module 2"'::jsonb, 'MCK-01: title is Module 2');
select is((select array_agg(q ->> 'id' order by ord) from jsonb_array_elements(pg_temp.st('m3a2') -> 'questions') with ordinality x(q, ord)),
  (select array_agg(id::text order by n) from t_q where n between 45 and 66), 'MCK-01: module 2 is the routed M2H module in slot order');
select is(pg_temp.st('m3a2b') ->> 'attempt_id', pg_temp.st('m3a2') ->> 'attempt_id', 'MCK-01: a second start_mock_module2 returns the same module');
select results_eq($$ select kind::text, module_no, mock_attempt_group, mock_form_id, time_limit_s, started_at
    from public.attempts where id = pg_temp.att('m3a2') $$,
  $$ select 'mock_module', 2, pg_temp.grp('m3a1'),
            (select id from public.mock_forms where set_no = 3 and form_no = 1 and module = 'M2H'), 2100, now() $$,
  'MCK-01: module 2 attempt uses the routed form row and starts now');
select is((select m2_attempt_id from private.mock_runs where group_id = pg_temp.grp('m3a1')), pg_temp.att('m3a2'),
  'MCK-01: the run points at module 2');
select ok(pg_temp.st('m3a2')::text !~ '(correct_answer|explanation|is_correct|"key"|SECRET|route)', 'MCK-01: module 2 payload has no key or route');
select tests.authenticate_as('mk3_a');
select is(public.get_mock_stage(pg_temp.grp('m3a1')) ->> 'attempt_id', pg_temp.st('m3a2') ->> 'attempt_id', 'MCK-01: resume during module 2 returns module 2');
select tests.clear_authentication();
reset role;

-- finish module 2
select pg_temp.ans(pg_temp.att('m3a2'), 10);
select tests.authenticate_as('mk3_a');
insert into t_st select 'a_fin', public.submit_attempt(pg_temp.att('m3a2'));
select is(public.submit_attempt(pg_temp.att('m3a2')) ->> 'stage', 'finished', 'MCK-01: a second submit of module 2 is still finished');
select tests.clear_authentication();
reset role;
select is(pg_temp.st('a_fin') -> 'stage', '"finished"'::jsonb, 'MCK-01: submitting module 2 returns the finished stage');
select results_eq($$ select route, raw_m1, raw_m2, est_low, est_high from public.mock_results where group_id = pg_temp.grp('m3a1') $$,
  $$ select 'M2H', 14, 10, e.est_low, e.est_high from private.mock_estimate('M2H', 24) e $$,
  'MCK-01: result carries route, raws and the estimate of the total');
select is((select count(*)::int from public.mock_results where group_id = pg_temp.grp('m3a1')), 1, 'MCK-01: exactly one result');
select is((select sum((v ->> 'total')::int)::int from public.mock_results r, jsonb_each(r.domain_breakdown) x(k, v)
  where r.group_id = pg_temp.grp('m3a1')), 44, 'MCK-01: domain breakdown totals sum to 44');
select is((select sum((v ->> 'correct')::int)::int from public.mock_results r, jsonb_each(r.domain_breakdown) x(k, v)
  where r.group_id = pg_temp.grp('m3a1')), 24, 'MCK-01: domain breakdown corrects sum to the raw total');
select results_eq($$ select score_raw, score_total from public.attempts where id in (pg_temp.att('m3a1'), pg_temp.att('m3a2')) order by module_no $$,
  $$ values (14, 22), (10, 22) $$, 'MCK-01: both attempts carry their scores once the run is finished');
select ok((select finished_at is not null from private.mock_runs where group_id = pg_temp.grp('m3a1')), 'MCK-01: the run is finished');
select is((select attempts from public.skill_mastery where user_id = pg_temp.uid('mk3_a')), 44,
  'MCK-01: mastery counted all 44 answers once');
select tests.authenticate_as('mk3_a');
select is((select count(*)::int from public.attempt_answers where attempt_id in (pg_temp.att('m3a1'), pg_temp.att('m3a2'))), 44,
  'MCK-01: after the run finishes the student can read the answers of both modules');
select is((select count(*)::int from public.attempt_answers where attempt_id in (pg_temp.att('m3a1'), pg_temp.att('m3a2')) and is_correct), 24,
  'MCK-01: is_correct is readable after the run finishes');
select throws_ok($$ select public.get_attempt_review(pg_temp.att('m3a2')) $$, 'P0001', 'invalid_input', 'MCK-01: review of a mock module is still refused');
select is(public.get_mock_hub((select course_id from t_ids)) #>> '{forms,0,state}', 'finished', 'MCK-01: hub shows the form finished');
select results_eq($$ select (public.get_mock_hub((select course_id from t_ids)) #>> '{forms,0,est_low}')::int, (public.get_mock_hub((select course_id from t_ids)) #>> '{forms,0,est_high}')::int $$,
  $$ select est_low, est_high from t_est $$, 'MCK-01: hub shows the range');
select is(public.get_mock_hub((select course_id from t_ids)) -> 'active_run', 'null'::jsonb, 'MCK-01: no active run once finished');
select is(public.get_mock_hub((select course_id from t_ids)) #>> '{forms,1,state}', 'locked', 'MCK-01: the next form follows the unlock rule');
select tests.clear_authentication();
reset role;
select is((select attempts from public.skill_mastery where user_id = pg_temp.uid('mk3_a')), 44, 'MCK-01: a repeat submit did not apply mastery again');
select is(private.has_active_exam(pg_temp.uid('mk3_a')), false, 'MCK-01: nothing active after the run');

-- start_mock_module2 before module 1 is submitted; M2E routing with 13 correct
select tests.authenticate_as('mk3_b');
insert into t_st select 'b1', public.start_mock((select course_id from t_ids), 1);
select throws_ok($$ select public.start_mock_module2(pg_temp.grp('b1')) $$, 'P0001', 'invalid_input', 'MCK-01: module 2 before module 1 is submitted is invalid_input');
select tests.authenticate_as('mk3_a');
select throws_ok($$ select public.start_mock_module2(pg_temp.grp('b1')) $$, 'P0001', 'invalid_input', 'MCK-01: another student''s group is invalid_input');
select throws_ok($$ select public.start_mock_module2(null) $$, 'P0001', 'invalid_input', 'MCK-01: null group is invalid_input');
select tests.clear_authentication();
reset role;
select pg_temp.ans(pg_temp.att('b1'), 13);
select tests.authenticate_as('mk3_b');
select public.submit_attempt(pg_temp.att('b1'));
insert into t_st select 'b2', public.start_mock_module2(pg_temp.grp('b1'));
select tests.clear_authentication();
reset role;
select results_eq($$ select raw_m1, route from private.mock_runs where group_id = pg_temp.grp('b1') $$, $$ values (13, 'M2E') $$, 'MCK-01: 13 correct routes to M2E');
select is((select array_agg(q ->> 'id' order by ord) from jsonb_array_elements(pg_temp.st('b2') -> 'questions') with ordinality x(q, ord)),
  (select array_agg(id::text order by n) from t_q where n between 23 and 44), 'MCK-01: M2E route serves the M2E module');
select is(private.has_active_exam(pg_temp.uid('mk3_b')), true, 'MCK-01: the gap and module 2 count as an active exam');

-- C: the student disappears in module 1; one tick takes the run all the way to a result
select tests.authenticate_as('mk3_c');
insert into t_st select 'c1', public.start_mock((select course_id from t_ids), 1);
select tests.clear_authentication();
reset role;
update public.attempts set started_at = now() - interval '5 hours' where id = pg_temp.att('c1');
select tests.authenticate_as('mk3_c');
insert into t_st select 'c_stage', public.get_mock_stage(pg_temp.grp('c1'));
select tests.clear_authentication();
reset role;
select is(pg_temp.st('c_stage') ->> 'stage', 'finished', 'MCK-01: get_mock_stage after hours away returns finished');
select results_eq($$ select route, raw_m1, raw_m2, est_low, est_high from public.mock_results where group_id = pg_temp.grp('c1') $$,
  $$ select 'M2E', 0, 0, e.est_low, e.est_high from private.mock_estimate('M2E', 0) e $$, 'MCK-01: an empty run scores 0 on the easy route');
select is((select m1_submitted_at from private.mock_runs where group_id = pg_temp.grp('c1')),
  (select started_at + interval '2100 seconds' from public.attempts where id = pg_temp.att('c1')),
  'MCK-01: module 1 is closed at its deadline, not at tick time');
select is((select started_at from public.attempts a join private.mock_runs r on r.m2_attempt_id = a.id where r.group_id = pg_temp.grp('c1')),
  (select m1_submitted_at + interval '120 seconds' from private.mock_runs where group_id = pg_temp.grp('c1')),
  'MCK-01: module 2 started when the gap ended');
select is((select count(*)::int from public.attempt_answers aa join public.attempts a on a.id = aa.attempt_id where a.mock_attempt_group = pg_temp.grp('c1')), 44,
  'MCK-01: unanswered questions are rows counted wrong');
select is((select attempts from public.skill_mastery where user_id = pg_temp.uid('mk3_c')), 44, 'MCK-01: mastery applied for the abandoned run');

-- D: the gap is over but module 2 is not overdue; then module 2 overdue
select tests.authenticate_as('mk3_d');
insert into t_st select 'd1', public.start_mock((select course_id from t_ids), 1);
select tests.clear_authentication();
reset role;
select pg_temp.ans(pg_temp.att('d1'), 14);
select tests.authenticate_as('mk3_d');
select public.submit_attempt(pg_temp.att('d1'));
select tests.clear_authentication();
reset role;
select private.mock_tick(pg_temp.uid('mk3_d'));
select is((select m2_attempt_id from private.mock_runs where group_id = pg_temp.grp('d1')), null, 'MCK-01: tick inside the gap creates nothing');
update private.mock_runs set m1_submitted_at = now() - interval '200 seconds' where group_id = pg_temp.grp('d1');
select private.mock_tick(pg_temp.uid('mk3_d'));
select is((select a.started_at from public.attempts a join private.mock_runs r on r.m2_attempt_id = a.id where r.group_id = pg_temp.grp('d1')),
  now() - interval '80 seconds', 'MCK-01: tick after the gap starts module 2 at m1_submitted_at + gap');
select ok((select finished_at is null from private.mock_runs where group_id = pg_temp.grp('d1')), 'MCK-01: module 2 is still running');
select private.mock_tick(pg_temp.uid('mk3_d'));
select is((select count(*)::int from public.attempts where mock_attempt_group = pg_temp.grp('d1')), 2, 'MCK-01: tick is idempotent');
update public.attempts set started_at = now() - interval '2200 seconds'
where id = (select m2_attempt_id from private.mock_runs where group_id = pg_temp.grp('d1'));
select private.mock_tick(pg_temp.uid('mk3_d'));
select results_eq($$ select route, raw_m1, raw_m2 from public.mock_results where group_id = pg_temp.grp('d1') $$, $$ values ('M2H', 14, 0) $$,
  'MCK-01: an overdue module 2 is finished with unanswered counted wrong');
select private.mock_tick(pg_temp.uid('mk3_d'));
select is((select count(*)::int from public.mock_results where group_id = pg_temp.grp('d1')), 1, 'MCK-01: a finished run is not finished again');

-- E: the cron path, for a user who calls nothing
select tests.authenticate_as('mk3_e');
insert into t_st select 'e1', public.start_mock((select course_id from t_ids), 1);
select tests.clear_authentication();
reset role;
select pg_temp.ans(pg_temp.att('e1'), 14);
select tests.authenticate_as('mk3_e');
select public.submit_attempt(pg_temp.att('e1'));
select tests.clear_authentication();
reset role;
update private.mock_runs set m1_submitted_at = now() - interval '60 seconds' where group_id = pg_temp.grp('e1');
select private.expire_overdue_attempts();
select is((select m2_attempt_id from private.mock_runs where group_id = pg_temp.grp('e1')), null, 'MCK-01: cron does nothing while the gap is running');
update private.mock_runs set m1_submitted_at = now() - interval '300 seconds' where group_id = pg_temp.grp('e1');
select cmp_ok(private.expire_overdue_attempts(), '>=', 1, 'MCK-01: cron reports the run it moved');
select isnt((select m2_attempt_id from private.mock_runs where group_id = pg_temp.grp('e1')), null, 'MCK-01: cron creates module 2 after the gap');
update public.attempts set started_at = now() - interval '5000 seconds'
where id = (select m2_attempt_id from private.mock_runs where group_id = pg_temp.grp('e1'));
select private.expire_overdue_attempts();
select is((select count(*)::int from public.mock_results where group_id = pg_temp.grp('e1')), 1, 'MCK-01: cron finishes an overdue module 2 with a result');
select is(private.expire_overdue_attempts(), 0, 'MCK-01: cron with nothing due does nothing');

-- F: the enrolment expires and the set changes mid-run
select tests.authenticate_as('mk3_f');
insert into t_st select 'f1', public.start_mock((select course_id from t_ids), 1);
select tests.clear_authentication();
reset role;
select pg_temp.ans(pg_temp.att('f1'), 14);
update public.enrollments set expires_at = now() - interval '1 day', mock_set_no = 1 where user_id = pg_temp.uid('mk3_f');
select tests.authenticate_as('mk3_f');
select is(public.get_mock_hub((select course_id from t_ids)) -> 'active_run',
  jsonb_build_object('group_id', pg_temp.grp('f1'), 'set_no', 3, 'form_no', 1), 'MCK-01: active_run finds the run even after a set change');
select is(public.get_mock_hub((select course_id from t_ids)) -> 'set_no', '1'::jsonb, 'MCK-01: the hub follows the new set');
select is(public.submit_attempt(pg_temp.att('f1')) ->> 'stage', 'gap', 'MCK-01: module 1 submits after expiry and a set change');
insert into t_st select 'f2', public.start_mock_module2(pg_temp.grp('f1'));
select is(pg_temp.st('f2') -> 'module_no', '2'::jsonb, 'MCK-01: module 2 starts after expiry and a set change');
select tests.clear_authentication();
reset role;
select pg_temp.ans(pg_temp.att('f2'), 5);
select tests.authenticate_as('mk3_f');
select is(public.submit_attempt(pg_temp.att('f2')) ->> 'stage', 'finished', 'MCK-01: module 2 submits after expiry and a set change');
select tests.clear_authentication();
reset role;
select is((select raw_m2 from public.mock_results where group_id = pg_temp.grp('f1')), 5, 'MCK-01: the result is stored for the run');

-- permissions
set local role anon;
select throws_ok($$ select public.start_mock_module2(null) $$, '42501', null, 'MCK-01: anon cannot execute start_mock_module2');
reset role;
set local role authenticated;
select throws_ok($$ select public.start_mock_module2(null) $$, 'P0001', 'not_authenticated', 'MCK-01: start_mock_module2 checks the uid');
reset role;
select ok(not has_function_privilege('authenticated', 'private.mock_tick(uuid)', 'execute')
  and not has_function_privilege('authenticated', 'private.mock_finish_module1(uuid,timestamptz)', 'execute')
  and not has_function_privilege('authenticated', 'private.mock_finish_module2(uuid,timestamptz)', 'execute')
  and not has_function_privilege('authenticated', 'private.mock_create_module2(uuid,timestamptz)', 'execute')
  and not has_function_privilege('authenticated', 'private.mock_grade_attempt(uuid,timestamptz)', 'execute'),
  'MCK-01: task 3 helpers are not executable by API roles');
select ok(not has_function_privilege('anon', 'public.mock_attempt_visible(uuid)', 'execute'), 'MCK-01: anon cannot execute the policy helper');

select * from finish();
rollback;
