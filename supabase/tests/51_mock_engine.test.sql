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

select * from finish();
rollback;
